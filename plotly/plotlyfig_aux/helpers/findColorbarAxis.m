function colorbarAxis = findColorbarAxis(obj,colorbarHandle)
if isHG2    
    colorbarAxisIndex = find(arrayfun(@(x)(isequal(getappdata(x.Handle,'ColorbarPeerHandle'),colorbarHandle)),obj.State.Axis));
    % If the above returns empty then we are on a more recent Matlab
    % release where the appdata entry is called LayoutPeers
    if isempty(colorbarAxisIndex)
        colorbarAxisIndex = find(arrayfun(@(x)(isequal(getappdata(x.Handle,'LayoutPeers'),colorbarHandle)),obj.State.Axis));
    end
else
    colorbarAxisIndex = find(arrayfun(@(x)(isequal(getappdata(x.Handle,'LegendColorbarInnerList'),colorbarHandle) + ...
        isequal(getappdata(x.Handle,'LegendColorbarOuterList'),colorbarHandle)),obj.State.Axis));
end
colorbarAxis = obj.State.Axis(colorbarAxisIndex).Handle;
end
