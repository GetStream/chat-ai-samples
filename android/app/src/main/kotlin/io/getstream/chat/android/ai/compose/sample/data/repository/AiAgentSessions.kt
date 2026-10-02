/*
 * Copyright (c) 2014-2026 Stream.io Inc. All rights reserved.
 *
 * Licensed under the Stream License;
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    https://github.com/GetStream/stream-chat-android-ai/blob/main/LICENSE
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package io.getstream.chat.android.ai.compose.sample.data.repository

/**
 * Counts the chat screens that use the AI agent of each channel.
 *
 * The backend runs one agent per channel, and stopping it is not reference counted. Two
 * screens can use the same channel for a moment, e.g. a new chat that just got its channel
 * and the same chat opened from the drawer. So a screen stops the agent only when it was
 * the last one using it.
 */
public class AiAgentSessions {

    private val counts = mutableMapOf<String, Int>()

    /** Registers one more screen that uses the agent of [cid]. */
    @Synchronized
    public fun acquire(cid: String) {
        counts[cid] = (counts[cid] ?: 0) + 1
    }

    /**
     * Unregisters a screen that used the agent of [cid].
     *
     * @return true if no other screen uses the agent anymore, so it can be stopped.
     */
    @Synchronized
    public fun release(cid: String): Boolean {
        val count = (counts[cid] ?: return true) - 1
        if (count > 0) {
            counts[cid] = count
            return false
        }
        counts.remove(cid)
        return true
    }
}
