import { AIMessageComposer } from "@stream-io/chat-react-ai";
import { useEffect, useRef } from "react";
import { ChipBar } from "./ChipBar";
import {
	Channel,
	isImageFile,
	type LocalUploadAttachment,
	type UploadRequestFn,
} from "stream-chat";
import {
	useAttachmentsForPreview,
	useChannelActionContext,
	useChannelStateContext,
	useChatContext,
	useMessageComposer,
} from "stream-chat-react";
import { startAiAgent } from "../api";
import petSchema from "../../../schema/petSchema.json";

const isWatchedByAI = (channel: Channel) => {
	return Object.keys(channel.state.watchers).some((watcher) =>
		watcher.startsWith("ai-bot")
	);
};

export const Composer = () => {
	const { client } = useChatContext();
	const { updateMessage, sendMessage } = useChannelActionContext();
	const { channel, messages } = useChannelStateContext();
	const composer = useMessageComposer();

	const { attachments } = useAttachmentsForPreview();

	const lastMessage = messages?.at(-1);
	const chipOptions =
		lastMessage?.ai_generated && lastMessage?.options?.length
			? lastMessage.options
			: null;

	const handleChipSelect = async (label: string) => {
		composer.textComposer.setText(label);
		const composedData = await composer.compose();
		if (!composedData) return;
		composer.clear();
		updateMessage(composedData.localMessage);

		if (!channel.initialized) {
			await channel.watch();
		}

		const platform = "anthropic";
		const model = "claude-haiku-4-5";

		if (!isWatchedByAI(channel)) {
			await startAiAgent(channel, model, platform, petSchema);
		}

		await sendMessage(composedData);
	};

	useEffect(() => {
		if (!composer) return;

		const upload: UploadRequestFn = (file) => {
			const f = isImageFile(file) ? client.uploadImage : client.uploadFile;

			return f.call(client, file as File);
		};

		const previousDefault = composer.attachmentManager.doDefaultUploadRequest;

		composer.attachmentManager.setCustomUploadFn(upload);

		return () => composer.attachmentManager.setCustomUploadFn(previousDefault);
	}, [client, composer]);

	useEffect(() => {
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		const listener = channel.on('data_collection_complete' as any, (event: any) => {
			console.log('Data collection complete:', event.collected_data);
		});
		return () => listener.unsubscribe();
	}, [channel]);

	const seenNotificationIds = useRef(new Set<string>());
	
	useEffect(() => {
		return client.notifications.store.subscribe((state) => {
			for (const notification of state.notifications) {
				if (!seenNotificationIds.current.has(notification.id)) {
					seenNotificationIds.current.add(notification.id);
					client.notifications.startTimeout(notification.id, 5000);
				}
			}
		});
	}, [client]);

	return (
		<div className="tut__composer-container">
			{chipOptions && (
				<ChipBar options={chipOptions} onSelect={handleChipSelect} />
			)}
			<AIMessageComposer
				onChange={(e) => {
					const input = e.currentTarget.elements.namedItem(
						"attachments"
					) as HTMLInputElement | null;

					const files = input?.files ?? null;

					if (files) {
						composer.attachmentManager.uploadFiles(files);
					}
				}}
				onSubmit={async (e) => {
					const event = e;
					event.preventDefault();

					const target = event.currentTarget;

					const formData = new FormData(target);

					const message = formData.get("message");
					composer.textComposer.setText(message as string);

					const composedData = await composer.compose();

					if (!composedData) return;

					target.reset();
					composer.clear();

					updateMessage(composedData?.localMessage);

					if (!channel.initialized) {
						await channel.watch();
					}

				const platform = "anthropic";
				const model = "claude-haiku-4-5";

				if (!isWatchedByAI(channel)) {
					await startAiAgent(channel, model, platform, petSchema);
				}

					await sendMessage(composedData);

					if (
						typeof channel.data?.summary !== "string" ||
						!channel.data.summary.length
					) {
						// Skip summarise for now
						// const summary = await summarizeConversation(
						// 	message as string
						// ).catch(() => {
						// 	console.warn("Failed to summarize conversation");
						// 	return null;
						// });
						

						// if (typeof summary === "string" && summary.length > 0) {
						// 	await channel.update({ summary });
						// }
						
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
								composer.attachmentManager.uploadAttachment(
									attachment as LocalUploadAttachment
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
	</div>

					<AIMessageComposer.SubmitButton active={attachments.length > 0} />
				</div>
			</AIMessageComposer>
		</div>
	);
};
