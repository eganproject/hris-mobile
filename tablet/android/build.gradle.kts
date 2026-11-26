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

// Beberapa plugin (mis. tflite_flutter) menetapkan Java 11 tetapi tidak menetapkan target
// Kotlin, sehingga Kotlin ikut versi JDK (21) dan Gradle menolak build. Samakan target
// Kotlin dengan target Java milik modul itu sendiri.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        val javaTask = project.tasks.findByName(name.replace(Regex("Kotlin$"), "JavaWithJavac")) as? JavaCompile
        if (javaTask != null) {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTask.targetCompatibility),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
