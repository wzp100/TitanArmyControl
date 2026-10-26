using Microsoft.UI.Reactor;
using Microsoft.UI.Reactor.Core;
using static Microsoft.UI.Reactor.Factories;
using static Microsoft.UI.Reactor.Core.Theme;
using TitanArmyControl.Core.Application;
using TitanArmyControl.Core.Controller;
using TitanArmyControl.Core.Model;
using TitanArmyControl.Platform.Windows;

namespace TitanArmyControl.Windows;

internal sealed class AppShell : Component
{
    private static readonly (string Id, string Key)[] Navigation =
    [
        ("scene", "scene"),
        ("game", "gamePlus"),
        ("dark", "darkOracle"),
        ("basic", "basic"),
        ("oled", "oledCare"),
        ("support", "support"),
        ("store", "store"),
    ];

    private readonly MonitorApplication _application;
    private readonly PlatformCapabilities _capabilities;

    public AppShell()
    {
        var catalog = new WindowsDisplayCatalog();
        _application = new MonitorApplication(catalog);
        _capabilities = catalog.Capabilities;
    }

    public override Element Render()
    {
        var (state, setState) = UseState(_application.State, threadSafe: true);
        var (busy, setBusy) = UseState(false, threadSafe: true);
        var (page, setPage) = UseState("scene");
        var (language, setLanguage) = UseState("zh");

        void RunOperation(Func<OperationResult> operation)
        {
            setBusy(true);
            Task.Run(() =>
            {
                try
                {
                    operation();
                    setState(_application.State);
                }
                finally
                {
                    setBusy(false);
                }
            });
        }

        void RefreshDisplays() =>
            RunOperation(() => _application.Refresh(thorough: true));

        void SelectDisplay(string id) =>
            RunOperation(() => _application.Select(id));

        void Apply(Action<MonitorController> operation) =>
            RunOperation(() => _application.Invoke(operation));

        UseEffect(
            () =>
            {
                RefreshDisplays();
                return () => _application.Dispose();
            },
            []);

        var selected = state.Displays.FirstOrDefault(x => x.Id == state.SelectedDisplayId);
        var content = Pages.Build(page, language, state, _capabilities, Apply);

        return FlexColumn(
            Toolbar(language, setLanguage, state, busy, RefreshDisplays),
            FlexRow(
                Sidebar(language, page, setPage, state, SelectDisplay),
                ScrollView(
                    VStack(
                        16,
                        PageHeader(page, language, selected),
                        state.Error is { Length: > 0 }
                            ? UiComponents.StatusNotice(state.Error, error: true)
                            : Empty(),
                        state.Notice is { Length: > 0 }
                            ? UiComponents.StatusNotice(state.Notice, error: false)
                            : Empty(),
                        selected is null && !busy
                            ? UiComponents.Card(
                                Strings.Get(language, "noDisplay"),
                                Strings.Get(language, "hidRequired"),
                                Button(Strings.Get(language, "refresh"), RefreshDisplays)
                                    .AutomationName(Strings.Get(language, "refresh")))
                            : content
                    ).Padding(horizontal: 28, vertical: 22)
                ).Flex(grow: 1)
            ).Flex(grow: 1)
        ).Backdrop(BackdropKind.Mica);
    }

    private static Element Toolbar(
        string language,
        Action<string> setLanguage,
        MonitorApplicationState state,
        bool busy,
        Action refresh) =>
        FlexRow(
            VStack(
                2,
                TextBlock("TitanArmyControl").FontSize(17).SemiBold(),
                Caption("P275MV PLUS").Foreground(SecondaryText)
            ).Flex(grow: 1),
            HStack(
                10,
                TextBlock(state.IsConnected
                        ? Strings.Get(language, "connected")
                        : Strings.Get(language, "disconnected"))
                    .FontSize(12)
                    .Foreground(state.IsConnected ? SystemSuccess : SecondaryText),
                Button(language == "zh" ? "EN" : "中文", () =>
                        setLanguage(language == "zh" ? "en" : "zh"))
                    .AutomationName(Strings.Get(language, "switchLanguage"))
                    .SubtleButton(),
                Button(busy ? "…" : Strings.Get(language, "refresh"), refresh)
                    .AutomationName(Strings.Get(language, "refresh"))
                    .IsEnabled(!busy)
            )
        )
        .FlexPadding(horizontal: 20, vertical: 12)
        .Background(CardBackground);

    private static Element Sidebar(
        string language,
        string page,
        Action<string> setPage,
        MonitorApplicationState state,
        Action<string> selectDisplay) =>
        Border(
            VStack(
                4,
                ForEach(
                    state.Displays,
                    display => Button(
                            display.Label,
                            () => selectDisplay(display.Id)
                        )
                        .AutomationName(display.Label)
                        .SubtleButton()
                        .WithKey(display.Id)
                ),
                TextBlock(Strings.Get(language, "language"))
                    .FontSize(11)
                    .SemiBold()
                    .Foreground(SecondaryText)
                    .Padding(horizontal: 8, vertical: 10),
                ForEach(
                    Navigation,
                    item => Button(
                            Strings.Get(language, item.Key),
                            () => setPage(item.Id)
                        )
                    .AutomationName(Strings.Get(language, item.Key))
                    .Background(page == item.Id ? Accent : ControlFill)
                    .Foreground(page == item.Id
                        ? Theme.Ref("TextOnAccentFillColorPrimaryBrush")
                        : PrimaryText)
                    .HorizontalContentAlignment(
                        Microsoft.UI.Xaml.HorizontalAlignment.Left)
                    .WithKey(item.Id)
                )
            ).Padding(12)
        )
        .Width(218)
        .Background(LayerFill)
        .BorderThickness(0, 0, 1, 0)
        .WithBorder(DividerStroke, 1);

    private static Element PageHeader(
        string page,
        string language,
        DisplayDescriptor? selected)
    {
        var key = page switch
        {
            "scene" => "sceneTitle",
            "game" => "gameTitle",
            "dark" => "darkTitle",
            "basic" => "basicTitle",
            "oled" => "oledTitle",
            "support" => "supportTitle",
            "store" => "storeTitle",
            _ => "basicTitle",
        };
        var descriptionKey = page switch
        {
            "scene" => "sceneDesc",
            "game" => "gameDesc",
            "dark" => "darkDesc",
            "basic" => "basicDesc",
            "oled" => "oledDesc",
            "support" => "supportDesc",
            "store" => "storeDesc",
            _ => "basicDesc",
        };

        return VStack(
            4,
            TextBlock(Strings.Get(language, key)).FontSize(26).Bold(),
            Caption(Strings.Get(language, descriptionKey)).Foreground(SecondaryText),
            Caption(selected?.Label ?? Strings.Get(language, "noDisplay"))
                .FontSize(11)
                .Foreground(Accent)
        );
    }
}
