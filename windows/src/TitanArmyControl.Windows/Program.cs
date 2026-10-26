using Microsoft.UI.Reactor;
using TitanArmyControl.Windows;

ReactorApp.Run<AppShell>(
    "TitanArmyControl",
    width: 1180,
    height: 760,
    icon: WindowIcon.FromPath(
        Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico")));
