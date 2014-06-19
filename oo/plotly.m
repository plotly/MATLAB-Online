classdef plotly
    % PLOTLY
    %  Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        User     = '';
        Response = '';
    end
    
    properties(Access = private)
        Key = '';
    end
    
    methods
        
        % CONSTRUCTOR
        function obj = plotly(user,key)
            % PLOTLY Sign into plot.ly
            
            % No inputs
            if nargin == 0
                % Try to load previously saved credentials ...
                try
                    obj = obj.loadcredentials;
                % ... try to sign up
                catch
                    obj.signup;
                end
            % Use provided credentials    
            elseif nargin == 2
                obj.User = user;
                obj.Key  = key;
            end
        end
        
        % CONVERSION of Matlab figuyre to plot.ly
        function obj = fig2plotly(obj, varargin)
            % FIG2PLOTLY Converts a Matlab figure object into a Plotly figure
            
            %   [response] = fig2plotly()
            %   [response] = fig2plotly(gcf)
            %   [response] = fig2plotly(f)
            %   [response] = fig2plotly(gcf, 'property', value, ...)
            %   [response] = fig2plotly(f, 'property', value, ...)
            %       gcf - root figure object in the form of a double.
            %       f - root figure object in the form of a struct. Use f = get(gcf); to
            %           get the current figure struct.
            %       List of valid properties:
            %           'name' - ('untitled')string, name of the plot
            %           'strip' - (false)boolean, ignores all styling, uses plotly defaults
            %           'open' - (true)boolean, opens a browser window with plot result
            %       response - a struct containing the result info of the plot
            %
            % For full documentation and examples, see https://plot.ly/api
            
            %default input
            f = get(gcf);
            plot_name = 'untitled';
            strip_style = false;
            open_browser = true;
            
            switch numel(varargin)
                case 0
                case 1
                    if isa(varargin{1}, 'double')
                        f = get(varargin{1});
                    end
                    if isa(varargin{1}, 'struct')
                        f = varargin{1};
                    end
                otherwise
                    if isa(varargin{1}, 'double')
                        f = get(varargin{1});
                    end
                    if isa(varargin{1}, 'struct')
                        f = varargin{1};
                    end
                    if mod(numel(varargin),2)~=1
                        error('Invalid number of arguments')
                    else
                        for i=2:2:numel(varargin)
                            if strcmp('strip', varargin{i})
                                strip_style = varargin{i+1};
                            end
                            if strcmp('name', varargin{i})
                                plot_name = varargin{i+1};
                            end
                            if strcmp('open', varargin{i})
                                open_browser = varargin{i+1};
                            end
                        end
                    end
             end
            
            % convert figure into data and layout data structures
            [data, layout, title] = convertFigure(f, strip_style);
            
            if numel(title)>0 && strcmp('untitled', plot_name)
                plot_name = title;
            end
            
            % send graph request
            origin       = 'plot';
            structargs   = struct('layout', layout, 'filename',plot_name, 'fileopt', 'overwrite');
            obj.Response = makecall(data, obj.User, obj.Key, origin, structargs);
            
            if open_browser
                status = dos(['open ' obj.Response.url ' > nul 2> nul']);
                if status==1
                    status = dos(['start ' obj.Response.url ' > nul 2> nul']);
                end
            end
            
        end
        
        function obj = plot(obj,varargin)
            obj = plothelper(obj, @plot, varargin);
        end
        
        % SAVE
        function obj = savecredentials(obj)
            % SAVECREDENTIALS Save/overwrite plotly authentication credentials
            
            % Call external
            savecredentials(obj.User,obj.Key)
        end
    end
    
    methods(Access = private)
        
        function obj = plothelper(obj, fun, inputs)
            % Create invisible figure and axes
            hf = figure('visible','off');
            ha = axes('parent',hf);
            % Invoke matlab function 
            fun(ha, inputs{:})
            % Convert figure
            obj = obj.fig2plotly(hf);
            % Cleanup
            delete([hf,ha])
        end
        
        function obj = signup(obj)
            % SIGNUP
            
            % Call external
            response = signup;
            if isempty(response), return, end
            obj.User = response.un;
            obj.Key  = response.api_key;
        end
        
        function obj = loadcredentials(obj)
            % LOADCREDENTIALS
            
            % Credentials file name
            userhome = getuserdir();
            if ispc
                filename = fullfile(userhome, 'plotly', 'credentials');
            else
                filename = fullfile(userhome,'.plotly', '.credentials');
            end
            
            % Check if credentials file exist
            if ~exist(filename, 'file')
                error('Plotly:CredentialsNotFound',...
                    ['It looks like you haven''t set up your plotly '...
                    'account credentials yet.\nTo get started, save your '...
                    'plotly username and API key by calling:\n'...
                    '>>> saveplotlycredentials(username, api_key)\n\n'...
                    'For more help, see https://plot.ly/MATLAB or contact '...
                    'chris@plot.ly.']);
            end
            
            % Open file
            fileID = fopen(filename, 'r');
            if(fileID == -1)
                error('plotly:loadcredentials', ...
                    ['There was an error reading your credentials file at '...
                    filename '. Contact chris@plot.ly for support.']);
            end
            
            % Read in credentials
            credentials = fread(fileID, [1,inf],'*char');
            credentials = json2struct(credentials);
            status = fclose(fileID);
            
            % Save state
            obj.User = credentials.username;
            obj.Key  = credentials.api_key;
            
            % Printf result
            if status == 0, fprintf('Credentials successfully loaded.\n'),end
        end
    end

end