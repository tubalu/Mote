import SwiftUI

struct RootPaletteView: View {
    @Environment(AppCore.self) private var core
    @Environment(PaletteState.self) private var vm
    @Environment(AppIndex.self) private var appIndex
    @Environment(FavoritesStore.self) private var favorites
    @Environment(VisibilityStore.self) private var visibility
    @Environment(AppSettings.self) private var settings
    @FocusState private var searchFocused: Bool
    /// Which in-window menu is open; at most one, so the state cannot disagree with itself.
    @State private var openMenu: OpenMenu?
    /// Sampled once by `openActions`, so the Quit row can't appear while the menu is up.
    @State private var selectionIsRunning = false
    /// Highlighted row of whichever menu is open; each open path sets where it starts.
    @State private var menuSelection = 0
    /// The pending scroll request; modes are exclusive, so one piece of state serves all.
    @State private var scroll = ScrollIntent(kind: .top)

    /// Compact vs. full; the source of truth is on `AppCore`, so the two can't disagree.
    private var isCollapsed: Bool { core.paletteCoordinator.paletteIsCollapsed }

    /// The launcher screen: its rows are the visible order the flat selection indexes.
    private var screen: LauncherScreen {
        LauncherScreen(
            appIndex: appIndex, favorites: favorites, visibility: visibility,
            core: core, vm: vm, running: selectionIsRunning,
            openActions: openActions,
            scrollToFollow: { scroll = ScrollIntent(kind: .follow) })
    }

    /// Selection clamped into the results: one source for highlight, preview and activation.
    private func selection(count: Int) -> Int {
        count == 0 ? 0 : min(max(vm.selection, 0), count - 1)
    }

    private func selection(in screen: LauncherScreen) -> Int {
        selection(count: screen.rows.count)
    }

    private var menuOpen: Bool { openMenu != nil }

    /// The Actions menu for the current selection, or nil when it has no actions.
    private var actionsContent: PopoverMenuContent? {
        let screen = screen
        return screen.actions(at: selection(in: screen))
    }

    /// The bottom-left app menu content (About / Settings).
    private var appMenuContent: PopoverMenuContent {
        PopoverMenuContent(items: [
            PopoverMenuItem(title: "About Mote", systemImage: "info.circle") {
                core.settingsCoordinator.showAbout()
            },
            PopoverMenuItem(title: "Settings", systemImage: "gearshape", shortcut: "⌘,") {
                core.settingsCoordinator.showSettings()
            }
        ])
    }

    /// Whichever menu is open — the one source `moveMenu` and `activateMenuItem` address rows through.
    private var menuContent: PopoverMenuContent? {
        switch openMenu {
        case .actions: return actionsContent
        case .app: return appMenuContent
        case nil: return nil
        }
    }

    var body: some View {
        let screen = screen
        let count = screen.rows.count
        let sel = selection(count: count)
        let showActionGroup = count > 0 && screen.hasPrimaryAction(at: sel)

        return Group {
            if isCollapsed {
                Color.clear
            } else {
                screen.body(selection: sel, scroll: scroll)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isCollapsed {
                bottomBar(
                    pillLabel: screen.primaryActionTitle, showActionGroup: showActionGroup)
            }
        }
        .overlay(alignment: .top) { topDragStrip }
        .overlay {
            Color.black.opacity(0.001)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { _ in closeMenus() })
                .allowsHitTesting(menuOpen)
        }
        .overlay(alignment: .bottomLeading) {
            if openMenu == .app {
                let content = appMenuContent
                PopoverMenu(
                    header: content.header, items: content.items, selection: $menuSelection,
                    onActivate: activateMenuItem
                )
                .padding(Self.menuInset)
                .transition(Self.menuTransition(.bottomLeading))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if openMenu == .actions, let content = actionsContent {
                PopoverMenu(
                    header: content.header, items: content.items, selection: $menuSelection,
                    onActivate: activateMenuItem
                )
                .padding(Self.menuInset)
                .transition(Self.menuTransition(.bottomTrailing))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.panelScrim)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
        .onChange(of: vm.focusToken) {
            searchFocused = true
            openMenu = nil
        }
        .onChange(of: vm.query) {
            vm.selection = 0
            scroll = ScrollIntent(kind: .top)
        }
        .onChange(of: vm.resetToken) {
            scroll = ScrollIntent(kind: .top)
        }
        .onChange(of: vm.favoriteSlotToken) { activateFavoriteSlotShortcut() }
        .onChange(of: openMenu) {
            vm.menuOpen = menuOpen
        }
        .onAppear { searchFocused = true }
        .onChange(of: core.paletteCoordinator.paletteIsCollapsed) {
            core.paletteCoordinator.syncPaletteSize()
        }
        .onKeyPress(keys: [.downArrow], phases: [.down, .repeat]) { press in
            if let reorder = moveFavorite(1, modifiers: press.modifiers) { return reorder }
            if isCollapsed {
                vm.selection = 0
                core.paletteCoordinator.expandFromCompact()
                return .handled
            }
            if menuOpen {
                moveMenu(1)
                return .handled
            }
            moveVertically(1)
            return .handled
        }
        .onKeyPress(keys: [.upArrow], phases: [.down, .repeat]) { press in
            if let reorder = moveFavorite(-1, modifiers: press.modifiers) { return reorder }
            if isCollapsed { return .ignored }
            if menuOpen {
                moveMenu(-1)
                return .handled
            }
            moveVertically(-1)
            return .handled
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            let command = press.modifiers.contains(.command)
            let option = press.modifiers.contains(.option)
            if menuOpen, !command, !option {
                activateMenuItem(menuSelection)
                return .handled
            }
            guard command || option else { return .ignored }
            let screen = screen
            let selection = selection(in: screen)
            if command { return screen.secondary(at: selection) ? .handled : .ignored }
            return .ignored
        }
        .onKeyPress(.escape) {
            switch PaletteEscapeAction.resolve(menuOpen: menuOpen, query: vm.query, mode: vm.mode) {
            case .closeMenu:
                closeMenus()
            case .clearQuery:
                vm.query = ""
            case .hidePalette:
                core.paletteCoordinator.hidePalette()
            }
            return .handled
        }
        .onKeyPress(.tab) { .handled }
        .onKeyPress(keys: ["k"], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            guard !isCollapsed else { return .handled }
            let screen = screen
            guard !screen.rows.isEmpty else { return .handled }
            guard screen.hasPrimaryAction(at: selection(in: screen)) else { return .handled }
            toggleActions()
            return .handled
        }
        .onKeyPress(keys: ["f", "F"], phases: .down) { press in
            guard press.modifiers.contains(.command), press.modifiers.contains(.shift),
                !isCollapsed
            else { return .ignored }
            guard screen.toggleFavorite(at: selection(in: screen)) else { return .ignored }
            if menuOpen { closeMenus() }
            return .handled
        }
        .onKeyPress(keys: ["q", "Q"], phases: .down) { press in
            guard press.modifiers.contains(.control), press.modifiers.contains(.shift),
                !isCollapsed
            else { return .ignored }
            return screen.quit(at: selection(in: screen)) ? .handled : .ignored
        }
    }

    private var topDragStrip: some View {
        Color.clear
            .frame(height: Theme.Size.headerPadding)
            .windowDraggable(settings.paletteDraggable, onBegan: beginDrag, onEnded: endDrag)
    }

    private func headerGutter(width: CGFloat) -> some View {
        Color.clear
            .frame(width: width)
            .windowDraggable(settings.paletteDraggable, onBegan: beginDrag, onEnded: endDrag)
    }

    private func beginDrag() { core.paletteCoordinator.beginPaletteDrag() }
    private func endDrag() { core.paletteCoordinator.endPaletteDrag() }

    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            headerGutter(width: Theme.Spacing.md * 2)
            Image(systemName: vm.mode.systemImage)
                .font(Theme.Typography.headerIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Size.headerIconSlot)
            headerGutter(width: Theme.Spacing.md)
            searchField
            if isCollapsed, settings.showFavoritesInCompactMode {
                let favorites = screen.compactFavorites
                if !favorites.isEmpty {
                    headerGutter(width: Theme.Spacing.md)
                    CompactFavoritesRow(
                        favorites: favorites,
                        showsOverflow: screen.hasUnshownFavorites,
                        onLaunch: { core.launcherCoordinator.launch($0) },
                        onOverflow: { core.paletteCoordinator.expandFromCompact() }
                    )
                }
            }
            headerGutter(width: Theme.Spacing.md * 2)
        }
        .frame(height: Theme.Size.headerHeight)
        .padding(.top, Theme.Size.headerPadding)
        .frame(maxWidth: .infinity)
    }

    private var searchField: some View {
        @Bindable var vm = vm
        return TextField("", text: $vm.query)
            .textFieldStyle(.plain)
            .font(Theme.Typography.searchField)
            .tint(Theme.Colors.textPrimary)
            .focused($searchFocused)
            .onSubmit(activateSelection)
            .frame(maxHeight: .infinity)
            .background(alignment: .leading) {
                if vm.query.isEmpty, !vm.isComposing {
                    Text(vm.mode.placeholder)
                        .font(Theme.Typography.searchField)
                        .foregroundStyle(Theme.Colors.textTertiary)
                        .lineLimit(1)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(Text(vm.mode.placeholder))
            .overlay {
                if settings.paletteDraggable {
                    TextTrailingDragHandle(
                        text: vm.query, font: Theme.Typography.searchFieldNSFont,
                        onBegan: beginDrag, onEnded: endDrag)
                }
            }
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: {
                vm.searchFieldFrame = $0
            }
    }

    private func bottomBar(pillLabel: String, showActionGroup: Bool) -> some View {
        HStack(spacing: 0) {
            appMenuButton
            Spacer()
            if showActionGroup { actionGroup(pillLabel: pillLabel) }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .frame(height: Theme.Size.bottomBarHeight)
        .frame(maxWidth: .infinity)
    }

    private var appMenuButton: some View {
        MenuCircleButton {
            if openMenu == .app { closeMenus() } else { open(.app, highlighting: 0) }
        }
    }

    private func actionGroup(pillLabel: String) -> some View {
        HStack(spacing: 2) {
            BarButton(action: activateSelection) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(pillLabel)
                        .font(Theme.Typography.bar)
                        .foregroundStyle(.primary)
                    KeyCapChip(text: "↵", style: .outline)
                }
            }
            BarButton(action: toggleActions) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text("Actions")
                        .font(Theme.Typography.bar)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    HStack(spacing: Theme.Spacing.xxs) {
                        KeyCapChip(text: "⌘", style: .outline)
                        KeyCapChip(text: "K", style: .outline)
                    }
                }
            }
        }
        .padding(Theme.Spacing.xs)
        .frosted(in: Capsule())
    }

    private func openActions() {
        selectionIsRunning = screen.isRunning(at: selection(in: screen))
        open(.actions, highlighting: 0)
    }

    private func toggleActions() {
        if openMenu == .actions {
            closeMenus()
        } else {
            openActions()
        }
    }

    private func open(_ menu: OpenMenu, highlighting row: Int) {
        menuSelection = row
        withAnimation(Self.menuAnimation) { openMenu = menu }
    }

    private func closeMenus() {
        withAnimation(Self.menuAnimation) { openMenu = nil }
    }

    private static let menuInset: CGFloat = 8
    private static let menuAnimation: Animation = .easeOut(duration: 0.14)

    private static func menuTransition(_ anchor: UnitPoint) -> AnyTransition {
        .opacity.combined(with: .scale(scale: 0.96, anchor: anchor))
    }

    private func move(_ delta: Int, in screen: LauncherScreen) {
        let count = screen.rows.count
        guard count > 0 else { return }
        vm.selection = min(max(selection(count: count) + delta, 0), count - 1)
        scroll = ScrollIntent(kind: .follow)
    }

    private func moveVertically(_ delta: Int) {
        move(delta, in: screen)
    }

    private func moveFavorite(_ delta: Int, modifiers: EventModifiers) -> KeyPress.Result? {
        guard modifiers.contains(.command), modifiers.contains(.option), !isCollapsed
        else { return nil }
        if screen.moveFavorite(delta, at: selection(in: screen)), menuOpen { closeMenus() }
        return .handled
    }

    private func moveMenu(_ delta: Int) {
        guard let count = menuContent?.items.count, count > 0 else { return }
        menuSelection = min(max(menuSelection + delta, 0), count - 1)
    }

    private func activateMenuItem(_ index: Int) {
        guard let items = menuContent?.items, items.indices.contains(index) else { return }
        items[index].action()
        closeMenus()
        searchFocused = true
    }

    private func activateFavoriteSlotShortcut() {
        guard let index = vm.favoriteSlotIndex else { return }
        _ = screen.launchFavorite(at: index)
    }

    private func activateSelection() {
        guard !isCollapsed else { return }
        let screen = screen
        screen.activate(at: selection(in: screen))
    }
}

private enum OpenMenu {
    case actions
    case app
}

private struct MenuCircleButton: View {
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Capsule().frame(width: 14, height: 1.5)
                Capsule().frame(width: 8, height: 1.5)
            }
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: Theme.Size.menuButton, height: Theme.Size.menuButton)
            .background(Circle().fill(hovered ? Theme.Colors.rowHover : Color.clear))
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .frosted(in: Circle())
    }
}

private struct ArmedHover: ViewModifier {
    @Environment(PaletteState.self) private var palette
    @Binding var hovered: Bool

    func body(content: Content) -> some View {
        content
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active: hovered = palette.hoverHighlightArmed
                case .ended: hovered = false
                }
            }
            .onChange(of: palette.hoverDisarmToken) { hovered = false }
    }
}

extension View {
    /// Row hover, lit only while the pointer moves; independent of the keyboard selection.
    func armedHover(_ hovered: Binding<Bool>) -> some View {
        modifier(ArmedHover(hovered: hovered))
    }
}

struct EmptyResults: View {
    let text: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.largeTitle)
                .symbolRenderingMode(.hierarchical).foregroundStyle(.tertiary)
            Text(text).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CompactFavoritesRow: View {
    let favorites: [AppEntry]
    let showsOverflow: Bool
    let onLaunch: (AppEntry) -> Void
    let onOverflow: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(Array(favorites.enumerated()), id: \.element.id) { index, app in
                CompactFavoriteButton(help: help(for: app, at: index)) {
                    onLaunch(app)
                } content: {
                    AppIconView(app: app)
                        .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                }
            }
            if showsOverflow {
                CompactFavoriteButton(help: "Show all  ↓", action: onOverflow) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(width: Theme.Size.rowIcon, height: Theme.Size.rowIcon)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Theme.Colors.controlSurface)
                                .padding(Theme.Spacing.xxs)
                        )
                }
            }
        }
    }

    private func help(for app: AppEntry, at index: Int) -> String {
        guard let digit = FavoriteSlots.digit(at: index) else { return app.name }
        return "\(app.name)  ⌘\(digit)"
    }
}

private struct CompactFavoriteButton<Content: View>: View {
    let help: String
    let action: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        Button(action: action) {
            content
                .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
