import com.android.build.api.artifact.SingleArtifact
import com.android.build.api.variant.BuiltArtifactsLoader
import org.gradle.api.DefaultTask
import org.gradle.api.file.DirectoryProperty
import org.gradle.api.file.RegularFileProperty
import org.gradle.api.provider.Property
import org.gradle.api.tasks.InputDirectory
import org.gradle.api.tasks.Internal
import org.gradle.api.tasks.OutputFile
import org.gradle.api.tasks.PathSensitive
import org.gradle.api.tasks.PathSensitivity
import org.gradle.api.tasks.TaskAction
import java.io.File
import java.nio.file.Files
import java.nio.file.StandardCopyOption

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

abstract class IncrementReleaseVersionCode : DefaultTask() {
    @get:Internal
    abstract val pubspecFile: RegularFileProperty

    @get:OutputFile
    abstract val versionCodeFile: RegularFileProperty

    @TaskAction
    fun increment() {
        val pubspec = pubspecFile.get().asFile
        val originalContent = pubspec.readText()
        val versionPattern = Regex("(?m)^(\\s*version:\\s*[^\\s+#]+\\s*\\+)(\\d+)(\\s*(?:#.*)?)$")
        val match = versionPattern.find(originalContent)
            ?: error("Cannot find a version in the form '<versionName>+<versionCode>' in ${pubspec.path}")
        val nextVersionCode = match.groupValues[2].toInt() + 1

        // 发布编号先落盘；即使后续打包失败，也不会在下次发布时复用该编号。
        pubspec.writeText(
            originalContent.replaceRange(
                match.groups[2]!!.range,
                nextVersionCode.toString(),
            ),
        )

        val output = versionCodeFile.get().asFile
        output.parentFile.mkdirs()
        output.writeText(nextVersionCode.toString())
    }
}

abstract class CopyVersionedReleaseApk : DefaultTask() {
    @get:InputDirectory
    @get:PathSensitive(PathSensitivity.RELATIVE)
    abstract val inputDirectory: DirectoryProperty

    @get:OutputFile
    abstract val outputFile: RegularFileProperty

    @get:Internal
    abstract val builtArtifactsLoader: Property<BuiltArtifactsLoader>

    @TaskAction
    fun copy() {
        val builtArtifacts = builtArtifactsLoader.get().load(inputDirectory.get())
            ?: error("Cannot load the release APK metadata")
        val artifact = builtArtifacts.elements.singleOrNull()
            ?: error("Expected one release APK, but found ${builtArtifacts.elements.size}")
        val output = outputFile.get().asFile

        output.parentFile.mkdirs()
        Files.copy(
            File(artifact.outputFile).toPath(),
            output.toPath(),
            StandardCopyOption.REPLACE_EXISTING,
        )
    }
}

android {
    namespace = "com.codex.loan.loan_repayment_manager"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Scheduled notifications require Java time APIs on older Android versions.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.codex.loan.loan_repayment_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        val incrementVersionCode = tasks.register<IncrementReleaseVersionCode>(
            "increment${variant.name.replaceFirstChar(Char::uppercaseChar)}VersionCode",
        ) {
            pubspecFile.set(rootProject.layout.projectDirectory.file("../pubspec.yaml"))
            versionCodeFile.set(layout.buildDirectory.file("generated/version-code/${variant.name}.txt"))

            // 每次真正执行 release 打包都需要生成一个新的发布编号。
            outputs.upToDateWhen { false }
        }
        val nextVersionCode = incrementVersionCode
            .flatMap { it.versionCodeFile }
            .map { it.asFile.readText().trim().toInt() }

        variant.outputs.forEach { output ->
            output.versionCode.set(nextVersionCode)
        }

        val copyVersionedApk = tasks.register<CopyVersionedReleaseApk>(
            "copy${variant.name.replaceFirstChar(Char::uppercaseChar)}ApkWithVersion",
        ) {
            builtArtifactsLoader.set(variant.artifacts.getBuiltArtifactsLoader())
            outputFile.set(
                nextVersionCode.map { versionCode ->
                    layout.buildDirectory.file(
                        "outputs/flutter-apk/loan-payment-${flutter.versionName}-B$versionCode.apk",
                    ).get()
                },
            )
        }

        // AGP 9 使用 Artifact API，在 APK 产出后自动执行版本化复制。
        variant.artifacts.use(copyVersionedApk)
            .wiredWith(CopyVersionedReleaseApk::inputDirectory)
            .toListenTo(SingleArtifact.APK)
    }
}
