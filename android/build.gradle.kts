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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// AGP 8+ requires every Android library to declare a namespace. Older
// plugins (amap_flutter_map / amap_flutter_location / amap_flutter_base@3.0.0)
// still rely on the `package` attribute in their AndroidManifest, which was
// removed from AGP as a namespace source. Patch them here after evaluation.
subprojects {
    afterEvaluate {
        if (project.name in setOf(
                "amap_flutter_map",
                "amap_flutter_location",
            )
        ) {
            project.extensions.findByName("android")?.let { ext ->
                try {
                    // Reflection keeps this file independent of AGP types.
                    val clazz = ext::class.java
                    val current =
                        clazz.getMethod("getNamespace").invoke(ext) as String?
                    if (current.isNullOrBlank()) {
                        clazz
                            .getMethod("setNamespace", String::class.java)
                            .invoke(
                                ext,
                                "com.amap.flutter.${project.name}",
                            )
                    }
                } catch (_: Throwable) {
                    // AGP < 7 doesn't need this; ignore.
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
