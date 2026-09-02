import BackgroundTasks
import SwiftUI

#if os(iOS)
    class AppDelegate: NSObject, UIApplicationDelegate {
        func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.pureiptv.refresh", using: nil) { task in
                self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
            return true
        }

        func application(_: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
            if identifier == "com.pureiptv.downloads" {
                DownloadDelegate.shared.backgroundCompletionHandler = completionHandler
            }
        }

        func handleAppRefresh(task: BGAppRefreshTask) {
            scheduleAppRefresh()

            let operation = Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                task.setTaskCompleted(success: true)
            }

            task.expirationHandler = {
                operation.cancel()
            }
        }

        func scheduleAppRefresh() {
            let request = BGAppRefreshTaskRequest(identifier: "com.pureiptv.refresh")
            request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                print("Could not schedule app refresh: \(error)")
            }
        }
    }
#else
    class AppDelegate: NSObject, UIApplicationDelegate {
        func scheduleAppRefresh() {
            // Not supported on tvOS
        }
    }
#endif
