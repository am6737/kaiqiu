import java.io.File

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// amap_flutter_map 3.0.0 still ships Flutter v1-embedding Java code
// (io.flutter.view.FlutterMain + PluginRegistry.Registrar) that modern
// Flutter has removed. We patch the pub-cache source in place so the
// plugin compiles on Flutter 3.x+. Idempotent — second run is a no-op.
fun patchAmapV1Embedding(androidDir: File) {
    val convertUtil = File(
        androidDir,
        "src/main/java/com/amap/flutter/map/utils/ConvertUtil.java",
    )
    if (convertUtil.exists()) {
        val original = convertUtil.readText()
        var patched = original
        patched = patched.replace(
            "import io.flutter.view.FlutterMain;",
            "import io.flutter.FlutterInjector;",
        )
        patched = patched.replace(
            "FlutterMain.getLookupKeyForAsset",
            "FlutterInjector.instance().flutterLoader().getLookupKeyForAsset",
        )
        if (patched != original) {
            convertUtil.writeText(patched)
        }
    }

    // Remove the registerWith(Registrar) method wholesale. Walk matching
    // braces so we don't get confused by anything inside the body.
    val pluginFile = File(
        androidDir,
        "src/main/java/com/amap/flutter/map/AMapFlutterMapPlugin.java",
    )
    if (pluginFile.exists()) {
        val src = pluginFile.readText()
        val marker = "public static void registerWith(PluginRegistry.Registrar registrar)"
        val start = src.indexOf(marker)
        if (start >= 0) {
            val openBrace = src.indexOf('{', start)
            if (openBrace > 0) {
                var depth = 0
                var closeBrace = -1
                for (i in openBrace until src.length) {
                    when (src[i]) {
                        '{' -> depth++
                        '}' -> {
                            depth--
                            if (depth == 0) {
                                closeBrace = i
                                break
                            }
                        }
                    }
                }
                if (closeBrace > 0) {
                    val patched = src.substring(0, start) +
                        "// v1 embedding registerWith removed for Flutter 3.x compat\n" +
                        src.substring(closeBrace + 1)
                    pluginFile.writeText(patched)
                }
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // AGP 8+ requires every Android library to declare a namespace. Older
    // plugins (amap_flutter_map / amap_flutter_location @3.0.0) still rely
    // on the `package` attribute in AndroidManifest, which AGP no longer
    // accepts as a namespace source. React to the android-library plugin
    // being applied and patch the namespace inline; compileSdk has to wait
    // for afterEvaluate because the plugin's own `android { ... }` block
    // runs after this callback and would otherwise re-pin it to 29.
    plugins.withId("com.android.library") {
        if (project.name in setOf("amap_flutter_map", "amap_flutter_location")) {
            project.extensions.findByName("android")?.let { ext ->
                val clazz = ext::class.java

                // 1. Inject the missing namespace AGP 8+ requires.
                try {
                    val current =
                        clazz.getMethod("getNamespace").invoke(ext) as String?
                    if (current.isNullOrBlank()) {
                        clazz
                            .getMethod("setNamespace", String::class.java)
                            .invoke(ext, "com.amap.flutter.${project.name}")
                    }
                } catch (_: Throwable) {
                    // AGP < 7 doesn't expose get/setNamespace; ignore.
                }

            }

            // 2. Bump compileSdk. The plugin pins 29 but its transitive
            //    AndroidX deps reference API 31+ attributes (e.g.
            //    android:attr/lStar) causing `verifyReleaseResources` to
            //    fail with "resource android:attr/lStar not found".
            //
            //    Must run in afterEvaluate: on AGP 8 the plugin's own
            //    `android { compileSdkVersion 29 }` block executes AFTER
            //    this plugins.withId callback returns and would clobber a
            //    value set inline. The DSL setter is also `setCompileSdk(Integer)`
            //    (Int? is nullable → boxed), so primitive-int reflection
            //    misses it — look it up by name + arity instead.
            project.afterEvaluate {
                project.extensions.findByName("android")?.let { ext ->
                    val clazz = ext::class.java
                    val setter = clazz.methods.firstOrNull {
                        it.name == "setCompileSdk" && it.parameterCount == 1
                    }
                    if (setter != null) {
                        try {
                            setter.invoke(ext, 34)
                        } catch (_: Throwable) {
                            // ignore — fall through to legacy string API
                        }
                    } else {
                        try {
                            clazz
                                .getMethod("setCompileSdkVersion", String::class.java)
                                .invoke(ext, "android-34")
                        } catch (_: Throwable) {
                            // Can't set compileSdk — let it fail loudly
                            // instead of silently compiling against an old API.
                        }
                    }
                }
            }

            // 3. AGP 8+ also refuses to process a manifest that still carries
            //    the legacy `package="..."` attribute, even when a namespace
            //    has been set programmatically. Strip it from the pub-cache
            //    file in place; the regex is idempotent so subsequent builds
            //    are no-ops and the modification is safe to share across
            //    projects that consume the same cached plugin.
            val manifest = project.file("src/main/AndroidManifest.xml")
            if (manifest.exists()) {
                val original = manifest.readText()
                val patched = original.replace(
                    Regex("""\s+package="[^"]*""""),
                    "",
                )
                if (patched != original) {
                    manifest.writeText(patched)
                }
            }

            // 4. amap_flutter_map still imports Flutter v1 embedding symbols
            //    (io.flutter.view.FlutterMain, PluginRegistry.Registrar) that
            //    have been deleted in Flutter 3.x. Rewrite the Java source to
            //    use FlutterInjector + drop the old registerWith entry point.
            if (project.name == "amap_flutter_map") {
                patchAmapV1Embedding(project.projectDir)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
