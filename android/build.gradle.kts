allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configure build directories for Flutter plugins to avoid "different roots" errors
// when project and Pub Cache are on different drives (e.g., D:\ and C:\)
subprojects {
    // Configure buildDir early, before tasks are created
    val projectPath = project.projectDir.absolutePath
    if (projectPath.contains("Pub\\Cache") || projectPath.contains("pub.dev") || 
        projectPath.contains("Pub/Cache") || projectPath.contains("pub-cache")) {
        // For plugins from Pub Cache, use their own build directory
        // This avoids cross-drive path issues
        val pluginBuildDir = project.projectDir.resolve("build")
        project.layout.buildDirectory.set(pluginBuildDir)
    }
    
    // Disable unit test tasks that cause issues with different drive roots
    afterEvaluate {
        tasks.matching { 
            it.name.contains("UnitTest", ignoreCase = true) || 
            it.name.contains("compileDebugUnitTest", ignoreCase = true) ||
            it.name.contains("testDebugUnitTest", ignoreCase = true)
        }.configureEach {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
