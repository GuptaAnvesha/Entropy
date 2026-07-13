allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build output to a path without spaces (Windows username space workaround)
val spacelessBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("C:/EntropyBuild").get()
rootProject.layout.buildDirectory.value(spacelessBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = spacelessBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
