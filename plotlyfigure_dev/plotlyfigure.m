classdef plotlyfigure < handle
    
    % plotlyfigure constructs an online Plotly plot.
    % There are three modes of use. The first is the
    % most base level approach of initializing a
    % plotlyfigure object and specify the data and layout
    % properties using Plotly declarartive syntax.
    % The second is a mid level useage which is based on
    % overloading the MATLAB plotting commands, such as
    % 'plot', 'scatter', 'subplot', ...
    % Lastly we have the third level of use
    
    %----CLASS PROPERTIES----%
    properties
        data; % data of the plot
        layout; % layout of the plot
        PlotOptions; % filename,fileopt,world_readable
        PlotlyDefaults;
        UserData; % credentials/configuration
        Response; % response of making post request
        State; % state of plot (FIGURE/AXIS/PLOTS)
        Verbose; % output procedural steps
        HandleGen; %object figure handle generator properties
    end
    
    events
        updateFigure
        updateAxes
        updateLegend
        updateData
        updateAnnotation
    end
    
    %----CLASS METHODS----%
    methods
        
        %----CONSTRUCTOR---%
        function obj = plotlyfigure(varargin)
            %check input structure
            if nargin > 1
                if mod(nargin,2) ~= 0 && ~ishandle(varargin{1})
                    error(['Oops! It appears that you did not initialize the Plotly figure object using the required ',...
                        '(,..''key'',''value'',...) input structure. Please try again or contact chuck@plot.ly',...
                        ' for any additional help!']);
                end
            end
            
            % core Plotly elements
            obj.data = {};
            obj.layout = struct();
            
            % user experience
            obj.Verbose = false;
            
            % plot options
            obj.PlotOptions.FileName = 'PLOTLYFIGURE';
            obj.PlotOptions.FileOpt = 'overwrite';
            obj.PlotOptions.WorldReadable = true;
            obj.PlotOptions.Open_URL = false;
            obj.PlotOptions.Strip = false;
            obj.PlotOptions.Visible = 'on';
            
            % plot option defaults (edit these for custom conversions)
            obj.PlotlyDefaults.MinTitleMargin = 80;
            obj.PlotlyDefaults.FigureIncreaseFactor = 2;
            obj.PlotlyDefaults.AxisLineIncreaseFactor = 1.5;
            obj.PlotlyDefaults.MarginPad = 0;
            obj.PlotlyDefaults.MaxTickLength = 20;
            obj.PlotlyDefaults.TitleHeight = 0.01;
            
            % check for some key/vals
            for a = 1:2:nargin
                if(strcmpi(varargin{a},'filename'))
                    obj.PlotOptions.Filename = varargin{a+1};
                end
                if(strcmpi(varargin{a},'fileopt'))
                    obj.PlotOptions.Fileopt= varargin{a+1};
                end
                if(strcmpi(varargin{a},'World_readable'))
                    obj.PlotOptions.World_readable = varargin{a+1};
                end
                if(strcmpi(varargin{a},'open'))
                    obj.PlotOptions.Open_URL = varargin{a+1};
                end
                if(strcmpi(varargin{a},'strip'))
                    obj.PlotOptions.Strip = varargin{a+1};
                end
                if(strcmpi(varargin{a},'visible'))
                    obj.PlotOptions.Visible = varargin{a+1};
                end
                if(strcmpi(varargin{a},'layout'))
                    obj.layout= varargin{a+1};
                end
                if(strcmpi(varargin{a},'data'))
                    obj.data = varargin{a+1};
                end
            end
            
            % user data
            try
                [obj.UserData.Credentials.Username,...
                    obj.UserData.Credentials.Api_Key,...
                    obj.UserData.Configuration.Plotly_Domain] = signin;
            catch
                error('Whoops! you must be signed in to initialize a plotlyfigure object!');
            end
            
            % generate figure and handle
            fig = figure;
            
            % default figure
            set(fig,'Name','PLOTLY FIGURE','color',[1 1 1],'ToolBar','none','NumberTitle','off','Visible',obj.PlotOptions.Visible);
            
            % figure state
            obj.State.Figure.Handle = fig;
            obj.State.Figure.NumAxes = 0;
            obj.State.Figure.NumPlots = 0;
            obj.State.Figure.NumLegends = 0;
            obj.State.Figure.NumAnnotations = 0;
            obj.State.Figure.Reference = [];
            
            % new child added listener (axes)
            addlistener(obj.State.Figure.Handle,'ObjectChildAdded',@(src,event)figureAddAxis(obj,src,event));
            % old child removed listener
            addlistener(obj.State.Figure.Handle,'ObjectChildRemoved',@(src,event)figureRemoveAxis(obj,src,event));
            
            % axis state
            obj.State.Axis = [];
            
            % plot state
            obj.State.Plot = [];
            
            % text state
            obj.State.Text = [];
            
            % legend state
            obj.State.Legend = [];
            
            % check to see if the first argument is a figure
            if nargin > 0
                if ishandle(varargin{1})
                    obj.State.Figure.Reference.Handle = varargin{1};
                    obj.convertFigure;
                else
                    % add default axis
                    axes;
                end
            else
                % add default axis
                axes;
            end
            
            % plot response
            obj.Response = {};
        end
        
        
        %----------------------EXTRACT PLOTLY INDICES---------------------%
        
        %----GET CURRENT AXIS INDEX ----%
        function currentAxisIndex = getAxisIndex(obj,axishan)
            currentAxisIndex = find(arrayfun(@(x)(eq(x.Handle,axishan)),obj.State.Axis));
        end
        
        %----GET CURRENT LEGEND INDEX ----%
        function currentLegendIndex = getLegendIndex(obj,legendhan)
            currentLegendIndex = find(arrayfun(@(x)(eq(x.Handle,legendhan)),obj.State.Legend));
        end
        
        %----GET CURRENT DATA INDEX ----%
        function currentDataIndex = getDataIndex(obj,plothan)
            currentDataIndex = find(arrayfun(@(x)(eq(x.Handle,plothan)),obj.State.Plot));
        end
        
        %----GET CURRENT ANNOTATION INDEX ----%
        function currentAnnotationIndex = getAnnotationIndex(obj,annothan)
            currentAnnotationIndex = find(arrayfun(@(x)(eq(x.Handle,annothan)),obj.State.Text));
        end
        
        %-------------------------USER METHODS----------------------------%
        
        %----GET OBJ.STATE.FIGURE.HANDLE ----%
        function plotlyFigureHandle = gpf(obj)
            plotlyFigureHandle = obj.State.Figure.Handle;
            set(0,'CurrentFigure', plotlyFigureHandle);
        end
        
        %----SEND PLOT REQUEST----%
        function obj = fig2plotly(obj)
            
            %update the figure
            update(obj); 
            
            %args
            args.filename = obj.PlotOptions.FileName;
            args.fileopt = obj.PlotOptions.FileOpt;
            args.world_readable = obj.PlotOptions.WorldReadable;
            
            %layout
            args.layout = obj.layout;
            
            %send to plotly
            response = plotly(obj.data,args);
            
            %update response
            obj.Response = response;
            
            %ouput url as hyperlink in command window if possible
            try
                desktop = com.mathworks.mde.desk.MLDesktop.getInstance;
                editor = desktop.getGroupContainer('Editor');
                if(~strcmp(response.url,'') && ~isempty(editor));
                    fprintf(['\nLet''s have a look: <a href="matlab:openurl(''%s'')">' response.url '</a>\n\n'],response.url)
                end
            end
            
        end
        
        %--------------------------TITLE CHECK----------------------------%
        
        function check = isTitle(obj,annothan)
            try
                check = obj.State.Text(obj.getAnnotationIndex(annothan)).Title; 
            catch
                check = false; 
            end
        end

        %-----------------------FIGURE CONVERSION-------------------------%
        
        %automatic figure conversion
        function obj = convertFigure(obj)
            % create temp figure
            tempfig = figure('Visible','off');
            % find axes of reference figure
            ax = findobj(obj.State.Figure.Reference.Handle,'Type','axes');
            for a = 1:length(ax)
                % copy them to tempfigure
                axtemp = copyobj(ax(a),tempfig);
                % clear the children
                cla(axtemp,'reset');
                % add axtemp to figure
                axnew = copyobj(axtemp,obj.State.Figure.Handle);
                % copy ax children to axtemp
                copyobj(allchild(ax(a)),axnew);
            end
            delete(tempfig);
        end
        
        
        %----------------------UPDATE PLOTLY FIGURE-----------------------%
        
        function obj = update(obj)
            
            %update figure
            updateFigure(obj);
            
            %update axes
            for n = 1:obj.State.Figure.NumAxes
                updateAxis(obj,n);
            end
            
            %update plots
            for n = 1:obj.State.Figure.NumPlots
                updateData(obj,n); 
            end
            
            %update annotations
            for n = 1:obj.State.Figure.NumAnnotations
                updateAnnotation(obj,n);
            end
            
        end
        
        %--------------------CALLBACK FUNCTIONS---------------------------%
        
        %----ADD AN AXIS TO THE FIGURE----%
        function obj = figureAddAxis(obj,~,event)
            % check for type axes
            if strcmp(get(event.Child,'Type'),'axes')
                %check for legend tag
                if strcmp(get(event.Child,'Tag'),'legend')
                    %update the number of legends
                    obj.State.Figure.NumLegends = obj.State.Figure.NumLegends + 1;
                    obj.State.Legend(obj.State.Figure.NumLegends).Handle = event.Child;
                else
                    % update the number of axes
                    obj.State.Figure.NumAxes = obj.State.Figure.NumAxes + 1;
                    %update the axis handle
                    obj.State.Axis(obj.State.Figure.NumAxes).Handle = event.Child;
                    %new child added
                    addlistener(obj.State.Axis(obj.State.Figure.NumAxes).Handle,'ObjectChildAdded',@(src,event)axisAddPlot(obj,src,event));
                    %old child removed
                    addlistener(obj.State.Axis(obj.State.Figure.NumAxes).Handle,'ObjectChildRemoved',@(src,event)axisRemovePlot(obj,src,event));
                    %update the text index
                    obj.State.Figure.NumAnnotations = obj.State.Figure.NumAnnotations + 1;
                    %add title to annotations
                    obj.State.Text(obj.State.Figure.NumAnnotations).Handle = event.Child.Title;
                    obj.State.Text(obj.State.Figure.NumAnnotations).Title = true;
                    obj.State.Text(obj.State.Figure.NumAnnotations).AssociatedAxis = obj.State.Axis(obj.State.Figure.NumAxes).Handle;
                end
            end
        end
        
        %----ADD A PLOT TO AN AXIS----%
        function obj = axisAddPlot(obj,~,event)
            % ignore empty string text
            if ~emptyStringText(event.Child);
                % separate text from non-text
               if strcmpi(get(event.Child,'Type'),'text')
                    %update the text index
                    obj.State.Figure.NumAnnotations = obj.State.Figure.NumAnnotations + 1;
                    %text handle
                    obj.State.Text(obj.State.Figure.NumAnnotations).Handle = event.Child;
                    obj.State.Text(obj.State.Figure.NumAnnotations).AssociatedAxis = event.Child.Parent;
                    obj.State.Text(obj.State.Figure.NumAnnotations).Title = false;
                else
                    % update the plot index
                    obj.State.Figure.NumPlots = obj.State.Figure.NumPlots + 1;
                    % plot handle
                    obj.State.Plot(obj.State.Figure.NumPlots).Handle = event.Child;
                    obj.State.Plot(obj.State.Figure.NumPlots).AssociatedAxis = event.Child.Parent;
                    obj.State.Plot(obj.State.Figure.NumPlots).Class = event.Child.classhandle.name;
                end
            end
        end
        
        %----REMOVE AN AXIS FROM THE FIGURE----%
        function obj = figureRemoveAxis(obj,~,event)
            if strcmp(event.Child.Type,'axes')
                %get current axis index
                currentAxis = obj.getAxisIndex(event.Child);
                % update the number of axes
                obj.State.Figure.NumAxes = obj.State.Figure.NumAxes - 1;
                % update the axis HandleIndexMap
                obj.State.Axis(currentAxis) = [];
            else
                %get current legend index
                currentLegend = obj.getLegendIndex(event.Child);
                % update the number of legends
                obj.State.Figure.NumLegend = obj.State.Figure.NumLegends - 1;
                % update the legend HandleIndexMap
                obj.State.Legend(currentLegend) = [];
            end
        end
        
        %----REMOVE A PLOT FROM AN AXIS----%
        function obj = axisRemovePlot(obj,~,event)
            if ~strcmpi(event.Child.Type,'text')
                % get current plot index
                currentPlot = obj.getDataIndex(event.Child);
                % update the plot index
                obj.State.Figure.NumPlots = obj.State.Figure.NumPlots - 1;
                % update the HandleIndexMap
                obj.State.Plot(currentPlot) = [];
                % is a title or not(empty annotation or legend)
            elseif obj.isTitle(event.Child) || ~(isempty(get(event.Child,'String')) || eq(event.Child,event.Source.ZLabel) || eq(event.Child,event.Source.XLabel) || eq(event.Child,event.Source.YLabel))
                % get current annotation index
                currentAnnotation = obj.getAnnotationIndex(event.Child);
                % update the text index
                obj.State.Figure.NumAnnotations = obj.State.Figure.NumAnnotations - 1;
                % update the HandleIndexMap
                obj.State.Text(currentAnnotation) = [];
            end
        end
    end
end

