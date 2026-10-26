using Microsoft.UI.Reactor;
using Microsoft.UI.Reactor.Core;
using static Microsoft.UI.Reactor.Factories;
using static Microsoft.UI.Reactor.Core.Theme;

namespace TitanArmyControl.Windows;

internal sealed record RangeControlProps(
    string Label,
    int Current,
    int Minimum,
    int Maximum,
    string ApplyLabel,
    Action<int> OnApply,
    bool Enabled = true);

internal sealed class RangeControl : Component<RangeControlProps>
{
    public override Element Render()
    {
        var (draft, setDraft) = UseState((double)Props.Current);
        UseEffect(() => setDraft((double)Props.Current), Props.Current);

        return VStack(
            6,
            HStack(
                8,
                TextBlock(Props.Label).SemiBold().Flex(grow: 1),
                Caption($"{draft:0}").Foreground(SecondaryText)
            ),
            HStack(
                10,
                Slider(draft, Props.Minimum, Props.Maximum, setDraft)
                    .Flex(grow: 1)
                    .IsEnabled(Props.Enabled),
                Button(Props.ApplyLabel, () => Props.OnApply((int)Math.Round(draft)))
                    .AutomationName(Props.ApplyLabel)
                    .IsEnabled(Props.Enabled)
            )
        );
    }
}

internal static class UiComponents
{
    public static Element Card(string title, string? description, params Element[] children) =>
        Border(
            VStack(
                12,
                VStack(
                    4,
                    TextBlock(title).FontSize(18).SemiBold(),
                    description is null
                        ? Empty()
                        : Caption(description).Foreground(SecondaryText)
                ),
                Group(children)
            ).Padding(18)
        )
        .Background(CardBackground)
        .CornerRadius(10)
        .WithBorder(CardStroke, 1);

    public static Element Field(string title, Element control) =>
        VStack(5, Caption(title).SemiBold(), control);

    public static Element StatusNotice(string text, bool error) =>
        Border(
            TextBlock(text)
                .Foreground(error ? SystemCritical : SecondaryText)
                .Padding(12)
        )
        .Background(CardBackground)
        .CornerRadius(8)
        .WithBorder(error ? SystemCritical : CardStroke, 1);

    public static Element Bullet(string text) =>
        HStack(
            8,
            TextBlock("•").Foreground(Accent),
            TextBlock(text).Foreground(SecondaryText).Flex(grow: 1)
        );

    public static Element DisabledFeature(string title, string reason) =>
        Border(
            VStack(
                6,
                HStack(
                    8,
                    TextBlock(title).SemiBold(),
                    TextBlock("HID").FontSize(11).SemiBold().Foreground(SystemCaution)
                ),
                Caption(reason).Foreground(SecondaryText)
            ).Padding(14)
        )
        .Background(ControlFill)
        .CornerRadius(8)
        .Opacity(0.75);

    public static Element Range(
        string label,
        int current,
        int minimum,
        int maximum,
        string applyLabel,
        Action<int> onApply,
        bool enabled = true) =>
        Component<RangeControl, RangeControlProps>(
            new(label, current, minimum, maximum, applyLabel, onApply, enabled));
}
