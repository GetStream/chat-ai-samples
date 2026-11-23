import { AIMessageComposer } from "stream-chat-react/ai-components";
import { useEffect, useRef } from "react";
import {
	isImageFile,
	type Channel,
	type LocalUploadAttachment,
	type UploadRequestFn,
} from "stream-chat";
import {
	useAttachmentsForPreview,
	useChannel,
	useChatContext,
	useMessageComposerController,
} from "stream-chat-react";
import { startAiAgent, summarizeConversation } from "../api";

const isWatchedByAI = (channel: Channel) => {
	return Object.keys(channel.state.watchers).some((watcher) =>
		watcher.startsWith("ai-bot"),
	);
};

export const Composer = () => {
	const { client } = useChatContext();
	const channel = useChannel();
	const composer = useMessageComposerController();
	// the first submit awaits channel creation and the agent start before sending
	const isSubmitting = useRef(false);

	const { attachments } = useAttachmentsForPreview();

	useEffect(() => {
		if (!composer) return;

		const upload: UploadRequestFn = async (fileLike) => {
			const request = { file: fileLike as File };
			const { file, thumb_url } = isImageFile(fileLike)
				? await client.uploadImage(request)
				: await client.uploadFile(request);

			if (!file) throw new Error("The upload returned no file URL");

			return { file, thumb_url };
		};

		const previousDefault = composer.attachmentManager.doDefaultUploadRequest;

		composer.attachmentManager.setCustomUploadFn(upload);

		return () => composer.attachmentManager.setCustomUploadFn(previousDefault);
	}, [client, composer]);

	return (
		<div className="tut__composer-container">
			<AIMessageComposer
				onChange={(e) => {
					const input = e.currentTarget.elements.namedItem(
						"attachments",
					) as HTMLInputElement | null;

					const files = input?.files ?? null;

					if (files) {
						composer.attachmentManager.uploadFiles(files);
					}
				}}
				onSubmit={async (e) => {
					const event = e;
					event.preventDefault();

					if (isSubmitting.current) return;

					const target = event.currentTarget;

					const formData = new FormData(target);

					const message = formData.get("message");
					const platformModel = formData.get("platform-model");

					composer.textComposer.setText(message as string);

					// nothing to send yet, e.g. an empty prompt or an upload still running
					if (!composer.hasSendableData) return;

					isSubmitting.current = true;
					// the prompt is already in the composer state
					target.reset();

					let result: Awaited<ReturnType<typeof composer.send>>;
					try {
						// creates the channel on its first message; does nothing for a watched channel
						await channel.watch();

						const [platform, model] = (platformModel as string).split("|");

						if (!isWatchedByAI(channel)) {
							await startAiAgent(channel, model, platform);
						}

						// composes the message, shows it in the list right away and clears the composer
						result = await composer.send();
					} finally {
						isSubmitting.current = false;
					}

					if (result === "nothing-to-send") return;

					if (result !== "sent") return;

					if (
						typeof channel.data?.custom?.summary !== "string" ||
						!channel.data.custom.summary.length
					) {
						const summary = await summarizeConversation(
							message as string,
						).catch(() => {
							console.warn("Failed to summarize");
							return null;
						});

						if (typeof summary === "string" && summary.length > 0) {
							await channel.updatePartial({ set: { summary } });
						}
					}
				}}
			>
				<AIMessageComposer.AttachmentPreview>
					{attachments.map((attachment) => (
						<AIMessageComposer.AttachmentPreview.Item
							key={attachment.localMetadata.id}
							file={attachment.localMetadata.file as File}
							state={attachment.localMetadata.uploadState}
							imagePreviewSource={
								attachment.thumb_url ||
								(attachment.localMetadata.previewUri as string)
							}
							onDelete={() => {
								composer.attachmentManager.removeAttachments([
									attachment.localMetadata.id,
								]);
							}}
							onRetry={() => {
								composer.attachmentManager.uploadFile(
									attachment as LocalUploadAttachment,
								);
							}}
						/>
					))}
				</AIMessageComposer.AttachmentPreview>
				<AIMessageComposer.TextInput name="message" />
				<div
					style={{
						display: "flex",
						gap: "1rem",
						justifyContent: "space-between",
						alignItems: "center",
					}}
				>
					<div style={{ display: "flex", gap: ".25rem", alignItems: "center" }}>
						<AIMessageComposer.FileInput name="attachments" />
						<AIMessageComposer.SpeechToTextButton />
						<AIMessageComposer.ModelSelect name="platform-model" />
					</div>

					<AIMessageComposer.SubmitButton active={attachments.length > 0} />
				</div>
			</AIMessageComposer>
		</div>
	);
};
