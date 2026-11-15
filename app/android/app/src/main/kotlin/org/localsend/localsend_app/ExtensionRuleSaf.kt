package org.localsend.localsend_app

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Log

private const val TAG = "ExtensionRuleSaf"

/**
 * Returns `{accessible, name}` for the folder behind a SAF tree or document URI.
 *
 * `accessible` is false when the folder is gone or the app no longer holds a
 * permission for it: the document provider then returns no row or refuses the
 * query. `name` is the display name reported by the provider, or null when the
 * folder is not accessible or the provider does not report one.
 */
fun getDirectoryInfo(context: Context, uriString: String): Map<String, Any?> {
    val uri = Uri.parse(uriString)
    if (uri.scheme != ContentResolver.SCHEME_CONTENT) {
        return mapOf("accessible" to false, "name" to null)
    }

    val documentUri = try {
        if (DocumentsContract.isTreeUri(uri)) {
            DocumentsContract.buildDocumentUriUsingTree(uri, DocumentsContract.getTreeDocumentId(uri))
        } else {
            uri
        }
    } catch (e: Exception) {
        Log.w(TAG, "Could not resolve $uriString", e)
        return mapOf("accessible" to false, "name" to null)
    }

    // fromDocumentUri returns null when the provider has no such document (deleted)
    // or denies access (permission revoked), which is exactly "not accessible".
    val document = FastDocumentFile.fromDocumentUri(context, documentUri)
    val accessible = document != null && document.isDirectory
    val name = document?.name?.takeIf { it.isNotEmpty() }

    return mapOf("accessible" to accessible, "name" to name)
}

/**
 * Drops the persistable permission of a folder that is no longer needed,
 * e.g. because the rule that referenced it was deleted.
 *
 * Best effort: a URI that is not persisted (anymore) or already gone must not
 * fail the caller.
 */
fun releasePersistablePermission(context: Context, uriString: String) {
    try {
        context.contentResolver.releasePersistableUriPermission(
            Uri.parse(uriString),
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
    } catch (e: Exception) {
        Log.w(TAG, "Could not release the permission of $uriString", e)
    }
}
