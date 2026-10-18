# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# --- DigiMemory Checker ---
# Readable crash stack traces in Play Console (line numbers survive R8).
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# The web page talks to the native side through Capacitor's JS bridge, which is
# looked up by name/reflection at runtime. Keep the bridge and every
# @JavascriptInterface method so R8 cannot rename or strip them.
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.getcapacitor.** { *; }
