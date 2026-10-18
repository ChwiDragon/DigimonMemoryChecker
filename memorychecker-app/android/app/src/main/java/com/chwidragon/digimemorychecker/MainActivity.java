package com.chwidragon.digimemorychecker;

import android.content.pm.PackageInfo;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.JavascriptInterface;
import android.webkit.WebView;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.view.ViewCompat;
import androidx.core.view.WindowCompat;
import androidx.core.view.WindowInsetsCompat;
import androidx.core.view.WindowInsetsControllerCompat;
import com.getcapacitor.BridgeActivity;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

public class MainActivity extends BridgeActivity {
    // From this WebView version on, the WebView passes the system bar / cutout insets to the page's
    // CSS env(safe-area-inset-*) itself (same threshold as Capacitor's SystemBars).
    private static final int WEBVIEW_SAFE_AREA_FIX = 140;

    // TXT EXPORT (logs, record): Android's "save as" screen (Storage Access Framework) writes only the
    // one file the user picks, so no storage permission is needed.
    private ActivityResultLauncher<String> saveLauncher;
    private String pendingText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        // Result launchers must be registered before the activity starts.
        saveLauncher = registerForActivityResult(new ActivityResultContracts.CreateDocument("text/plain"), this::writePendingText);
        super.onCreate(savedInstanceState);
        // Native backup for the JS Wake Lock API: keeps the screen on during a
        // match even if navigator.wakeLock is unavailable or gets released.
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        // Fullscreen: hide the status bar and the navigation bar. A swipe from the edge shows them
        // briefly. Hidden before the first frame so the page doesn't resize right after launch.
        hideSystemBars();
        if (getBridge() == null || getBridge().getWebView() == null) return;
        WebView webView = getBridge().getWebView();
        // The phone's "font size" setting would otherwise scale only the WebView's
        // text and push numbers/labels out of their fixed-size buttons.
        webView.getSettings().setTextZoom(100);
        // The page is always viewport-fit=cover, so keep the WebView full size from the start
        // (Capacitor shrinks it by the system bars until it has read the page, then grows it,
        // which re-lays out the whole screen) and let the page's env() padding handle notches.
        // Only the keyboard shrinks it, so RECORD's deck-name field stays above the keyboard.
        // (Older WebViews without env() support keep Capacitor's own handling.)
        if (webViewMajorVersion() >= WEBVIEW_SAFE_AREA_FIX && webView.getParent() instanceof View) {
            ViewCompat.setOnApplyWindowInsetsListener((View) webView.getParent(), (v, insets) -> {
                boolean keyboard = insets.isVisible(WindowInsetsCompat.Type.ime());
                v.setPadding(0, 0, 0, keyboard ? insets.getInsets(WindowInsetsCompat.Type.ime()).bottom : 0);
                return insets;
            });
        }
        // Called from the page as window.DigiNative.saveText(fileName, text) (only the app's own local page is loaded).
        webView.addJavascriptInterface(new NativeBridge(), "DigiNative");
    }

    private class NativeBridge {
        @JavascriptInterface
        public void saveText(String name, String text) {
            runOnUiThread(() -> {
                pendingText = text;
                try {
                    saveLauncher.launch(name);
                } catch (Exception e) {
                    pendingText = null;
                    notifySaved("fail");
                }
            });
        }
    }

    private void writePendingText(Uri uri) {
        String text = pendingText;
        pendingText = null;
        if (uri == null || text == null) {
            notifySaved("cancel");
            return;
        }
        try (OutputStream out = getContentResolver().openOutputStream(uri, "wt")) {
            if (out == null) throw new java.io.IOException("no stream");
            out.write(text.getBytes(StandardCharsets.UTF_8));
            notifySaved("ok");
        } catch (Exception e) {
            notifySaved("fail");
        }
    }

    private void notifySaved(String result) {
        if (getBridge() == null || getBridge().getWebView() == null) return;
        getBridge().getWebView().evaluateJavascript("window.onTextSaved && window.onTextSaved('" + result + "')", null);
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        // Hide the bars again after returning from another app, the notification shade or the save screen.
        if (hasFocus) hideSystemBars();
    }

    private void hideSystemBars() {
        WindowCompat.setDecorFitsSystemWindows(getWindow(), false);
        WindowInsetsControllerCompat controller = WindowCompat.getInsetsController(getWindow(), getWindow().getDecorView());
        controller.setSystemBarsBehavior(WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE);
        controller.hide(WindowInsetsCompat.Type.systemBars());
    }

    private int webViewMajorVersion() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return 0;
        PackageInfo info = WebView.getCurrentWebViewPackage();
        if (info == null || info.versionName == null) return 0;
        try {
            return Integer.parseInt(info.versionName.split("\\.")[0]);
        } catch (NumberFormatException e) {
            return 0;
        }
    }
}
