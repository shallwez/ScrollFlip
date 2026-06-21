import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: ScrollSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 25))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("滚动翻转")
                        .font(.title2.bold())
                    Text("独立调整鼠标滚轮")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            if !settings.hasAccessibilityPermission {
                permissionCard
            } else {
                controls
            }

            Divider()

            HStack {
                Circle()
                    .fill(settings.isMonitoring ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(settings.isMonitoring ? "正在监听鼠标滚轮" : "等待辅助功能权限")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(width: 330)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 18) {
            Toggle(isOn: $settings.reverseVertical) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("垂直滚动翻转")
                    Text(settings.reverseVertical ? "滚轮方向已反转" : "使用系统原始方向")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(BlueSwitchToggleStyle())

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("滚轮速度")
                    Spacer()
                    Text(speedLabel)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.speed, in: 0.25...3.0, step: 0.25)
                    .tint(.blue)
                HStack {
                    Text("慢")
                    Spacer()
                    Button("恢复默认") { settings.speed = 1.0 }
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("快")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Label("触控板滚动不会被修改", systemImage: "hand.point.up.left")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle(isOn: $settings.launchAtLogin) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("开机自动启动")
                    Text("登录 Mac 后在菜单栏自动运行")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(BlueSwitchToggleStyle())
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("需要辅助功能权限", systemImage: "lock.shield")
                .font(.headline)
            Text("用于读取并调整全局鼠标滚轮事件。应用不会记录按键或上传任何数据。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("授予权限") { settings.requestPermission() }
                    .buttonStyle(.borderedProminent)
                Button("打开系统设置") { settings.openAccessibilitySettings() }
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private var speedLabel: String {
        String(format: "%.2f×", settings.speed)
    }
}

private struct BlueSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Capsule()
                .fill(configuration.isOn ? Color.blue : Color.secondary.opacity(0.35))
                .frame(width: 46, height: 26)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(.white)
                        .frame(width: 22, height: 22)
                        .padding(2)
                        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                }
                .contentShape(Capsule())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
