allprojects {
    repositories {
        google()
        mavenCentral()
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
    // being applied and patch the namespace inline.
    //
    // This must happen BEFORE the evaluationDependsOn(":app") block below:
    // that forces subprojects to evaluate immediately, after which
    // afterEvaluate hooks would throw "project is already evaluated".
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

                // 2. Bump compileSdk. The plugin pins 29 but its transitive
                //    AndroidX deps reference API 31+ attributes (e.g.
                //    android:attr/lStar) causing `verifyReleaseResources` to
                //    fail with "resource android:attr/lStar not found".
                //    Setting it to 34 matches what Flutter's stable channel
                //    uses today and resolves all modern AndroidX attrs.
                try {
                    clazz
                        .getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                        .invoke(ext, 34)
                } catch (_: Throwable) {
                    // Fall back to the string-based API on older AGP.
                    try {
                        clazz
                            .getMethod("setCompileSdkVersion", String::class.java)
                            .invoke(ext, "android-34")
                    } catch (_: Throwable) {
                        // Can't set compileSdk — let it fail loudly instead
                        // of silently compiling against an old API.
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
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
