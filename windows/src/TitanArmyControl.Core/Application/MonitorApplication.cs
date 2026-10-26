using TitanArmyControl.Core.Controller;
using TitanArmyControl.Core.Model;

namespace TitanArmyControl.Core.Application;

public sealed record MonitorApplicationState(
    IReadOnlyList<DisplayDescriptor> Displays,
    string? SelectedDisplayId,
    DisplaySnapshot Snapshot,
    bool IsConnected,
    string? Notice,
    string? Error,
    DateTimeOffset LastUpdated)
{
    public static MonitorApplicationState Empty { get; } = new(
        [], null, new DisplaySnapshot(), false, null, null, DateTimeOffset.MinValue);
}

public readonly record struct OperationResult(bool Success, string? Error)
{
    public static OperationResult Ok { get; } = new(true, null);
    public static OperationResult Fail(Exception error) => new(false, error.Message);
    public static OperationResult Fail(string error) => new(false, error);
}

/// <summary>
/// UI-independent application facade. It owns display selection, snapshots, and
/// all controller operations. Reactor and SwiftUI only translate user input into
/// these calls and render the returned state.
/// </summary>
public sealed class MonitorApplication : IDisposable
{
    private readonly object _gate = new();
    private readonly IDisplayCatalog _catalog;
    private IMonitorConnection? _connection;
    private MonitorApplicationState _state = MonitorApplicationState.Empty;
    private bool _disposed;

    public MonitorApplication(IDisplayCatalog catalog)
    {
        _catalog = catalog;
    }

    public MonitorApplicationState State
    {
        get
        {
            lock (_gate)
            {
                return _state;
            }
        }
    }

    public OperationResult Refresh(bool thorough = false)
    {
        lock (_gate)
        {
            ObjectDisposedException.ThrowIf(_disposed, this);

            try
            {
                var displays = _catalog.Discover();
                var selected = displays.FirstOrDefault(
                                   x => x.Id == _state.SelectedDisplayId)
                               ?? displays.FirstOrDefault(x => x.IsTargetModel)
                               ?? displays.FirstOrDefault();

                if (selected is null)
                {
                    CloseConnectionLocked();
                    _state = new MonitorApplicationState(
                        displays, null, new DisplaySnapshot(), false,
                        "No display was found.", null, DateTimeOffset.Now);
                    return OperationResult.Ok;
                }

                if (_connection?.Descriptor.Id != selected.Id)
                {
                    CloseConnectionLocked();
                    _connection = _catalog.Connect(selected)
                        ?? throw new InvalidOperationException(
                            "The display does not expose a DDC/CI control channel.");
                }

                var snapshot = _connection.Controller.Snapshot(thorough);
                var readsUnavailable =
                    !snapshot.Brightness.Available &&
                    !snapshot.Contrast.Available &&
                    !snapshot.Volume.Available;

                _state = new MonitorApplicationState(
                    displays,
                    selected.Id,
                    snapshot,
                    true,
                    readsUnavailable
                        ? "The display is connected but did not return control data."
                        : null,
                    null,
                    DateTimeOffset.Now);
                return OperationResult.Ok;
            }
            catch (Exception error)
            {
                CloseConnectionLocked();
                _state = _state with
                {
                    IsConnected = false,
                    Error = error.Message,
                    LastUpdated = DateTimeOffset.Now,
                };
                return OperationResult.Fail(error);
            }
        }
    }

    public OperationResult Select(string displayId)
    {
        lock (_gate)
        {
            if (_state.Displays.All(x => x.Id != displayId))
            {
                return OperationResult.Fail($"Unknown display id '{displayId}'.");
            }

            _state = _state with { SelectedDisplayId = displayId };
        }

        return Refresh(thorough: true);
    }

    public OperationResult Invoke(Action<MonitorController> operation, bool refreshSnapshot = true)
    {
        lock (_gate)
        {
            ObjectDisposedException.ThrowIf(_disposed, this);
            if (_connection is null)
            {
                return OperationResult.Fail("No DDC/CI connection.");
            }

            try
            {
                operation(_connection.Controller);
                if (refreshSnapshot)
                {
                    _state = _state with
                    {
                        Snapshot = _connection.Controller.Snapshot(),
                        Notice = null,
                        Error = null,
                        LastUpdated = DateTimeOffset.Now,
                    };
                }

                return OperationResult.Ok;
            }
            catch (Exception error)
            {
                _state = _state with
                {
                    Error = error.Message,
                    LastUpdated = DateTimeOffset.Now,
                };
                return OperationResult.Fail(error);
            }
        }
    }

    public void DismissNotice()
    {
        lock (_gate)
        {
            _state = _state with { Notice = null, Error = null };
        }
    }

    public void Dispose()
    {
        lock (_gate)
        {
            if (_disposed)
            {
                return;
            }

            CloseConnectionLocked();
            _disposed = true;
        }
    }

    private void CloseConnectionLocked()
    {
        _connection?.Dispose();
        _connection = null;
    }
}
