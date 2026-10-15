/*
 * Copyright (c) 2014-2025 Stream.io Inc. All rights reserved.
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

package io.getstream.chat.android.ai.compose.sample.ui.components

import androidx.activity.compose.LocalActivity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.lifecycle.viewmodel.compose.viewModel

/**
 * Provides a ViewModelStore for the composable content, identified by [keys].
 *
 * The store is kept across configuration changes (e.g. a rotation), so the ViewModels of the
 * content keep their state. It is cleared when the content leaves the composition for another
 * reason, e.g. when the user opens another chat.
 */
@Composable
internal fun ViewModelStore(
    vararg keys: Any?,
    content: @Composable () -> Unit,
) {
    val key = keys.toList()
    val holder = viewModel<ViewModelStoreHolder>()
    val activity = LocalActivity.current
    val viewModelStore = remember(holder, key) { holder.storeFor(key) }
    val viewModelStoreOwner = remember(viewModelStore) {
        object : ViewModelStoreOwner {
            override val viewModelStore: ViewModelStore get() = viewModelStore
        }
    }

    // Clear the store when the content is disposed, unless the activity is only recreated
    DisposableEffect(holder, key) {
        onDispose {
            if (activity?.isChangingConfigurations != true) {
                holder.clear(key)
            }
        }
    }

    CompositionLocalProvider(LocalViewModelStoreOwner provides viewModelStoreOwner) {
        content()
    }
}

/**
 * Keeps the ViewModelStores of [ViewModelStore] by key, in the scope of the activity.
 */
internal class ViewModelStoreHolder : ViewModel() {

    private val stores = mutableMapOf<List<Any?>, ViewModelStore>()

    fun storeFor(key: List<Any?>): ViewModelStore = stores.getOrPut(key) { ViewModelStore() }

    fun clear(key: List<Any?>) {
        stores.remove(key)?.clear()
    }

    override fun onCleared() {
        stores.values.forEach(ViewModelStore::clear)
        stores.clear()
    }
}
