# AnyPopup

SwiftUI 弹窗基础设施：一个 `Popup` 协议、一条有序 Stack、一套命令式 API。

## 特性

- `ContainerPopupConfig` 与 `AnchoredPopupConfig` 编译期互斥；Anchored 不会响应式切换成 Container。
- Center/Top/Bottom 是 Container 的完整分支，同一个 Popup 可按容器、可用空间、键盘和 Reduce Motion 条件切换。
- Anchored 支持 anchor point、offset、屏幕边界避让，以及 Anchored 域内响应规则。
- 尺寸支持 available width/height、加减常量和最小/最大组合，不依赖 `UIScreen`。
- Anchored 内容可从 `EnvironmentValues.popupAnchoredGeometry` 读取最终避让结果，用于箭头等局部绘制。
- 后打开的 Popup 自然成为顶部；每个 Popup 独立 backdrop，每个 Stack 只有一个 Shield。
- `present`、`dismissPopup`、`dismissLastPopup`、`dismissAllPopups` 保持命令式调用。
- Scene 级独立 Window、标准 SwiftUI Environment 同步、键盘 frame 输入、异步关闭完成。
- `PopupSystemPresenter` 可在 Popup Stack 上展示系统 `UIViewController`，结束后恢复原 key window。

## 接入

```swift
import AnyPopup

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .registerPopups()
        }
    }
}
```

Container Popup：

```swift
struct BrowserPopup: Popup {
    let popupConfig = ContainerPopupConfig.center(
        CenterPopupConfig()
            .size(width: .fixed(720), height: .fraction(0.8))
            .transition(insertion: .opacity, removal: .opacity)
    )
    .when(
        .availableWidthLessThan(600),
        use: .bottom(
            BottomPopupConfig()
                .size(width: .fill, height: .fraction(0.9))
                .outsideInteraction(.dismissTop)
        )
    )
    .layoutTransition(.move(from: .bottom))

    var body: some View {
        Text("Browser")
    }
}

Task { await BrowserPopup().setCustomID("browser").present() }
```

Anchored Popup：

```swift
Button("Menu") {
    Task { await MenuPopup().present(anchoredTo: "menu") }
}
.trackAnchor("menu")
```

避让后对齐箭头：

```swift
struct MenuPopup: Popup {
    @Environment(\.popupAnchoredGeometry) private var anchoredGeometry

    var body: some View {
        MenuCard(arrowX: anchoredGeometry?.sourcePointInPopup.x)
    }

    var popupConfig: AnchoredPopupConfig {
        AnchoredPopupConfig()
            .size(width: .fixed(240), height: .content)
            .screenAvoidance(edges: .horizontal, padding: 16)
    }
}
```

完整可运行场景见 `Examples/PopupGallery`。

## License

Apache License 2.0. See `LICENSE` and `NOTICE`.
