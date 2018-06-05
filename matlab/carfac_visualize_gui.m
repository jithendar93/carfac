function carfac_visualize_gui
% SIMPLE_GUI2 Select a data set from the pop-up menu, then
% click one of the plot-type push buttons. Clicking the button
% plots the selected data in the axes.

f = figure('Visible','off','Position',[360,500,450,285]);

hreaddata = uicontrol('Style','pushbutton',...
             'String','Read Audio','Position',[315,260,70,25],...
             'Callback',@loaddata_Callback); 

hnaps    = uicontrol('Style','pushbutton',...
             'String','NAPS','Position',[315,230,70,25],...
             'Callback',@napsbutton_Callback);
hdecimnaps    = uicontrol('Style','pushbutton',...
             'String','Decim_NAPS','Position',[315,200,70,25],...
             'Callback',@decimnapsbutton_Callback);
         
hbm    = uicontrol('Style','pushbutton',...
             'String','BM','Position',[315,170,70,25],...
             'Callback',@bmbutton_Callback);         
hogc    = uicontrol('Style','pushbutton',...
             'String','OHC','Position',[315,140,70,25],...
             'Callback',@ohcbutton_Callback);         
hagc    = uicontrol('Style','pushbutton',...
             'String','AGC','Position',[315,110,70,25],...
             'Callback',@agcbutton_Callback);         
   
hagcstate = uicontrol('Style','pushbutton',...
             'String','AGC State','Position',[315,80,70,25],...
             'Callback',@agcstatebutton_Callback);
         
hpopup = uicontrol('Style','popupmenu',...
           'String',{'Closed Loop','Open Loop'},...
           'Position',[300,50,100,25],...
           'Callback',@popup_menu_Callback);

n_ears = 2;
n_stages = 4;
current_ear = 1;
current_stage = 1;
open_loop = 0;

ear_text = sprintf('Set Ear - %d', current_ear);
hcurrent_ear_text  = uicontrol('Style','text','String',ear_text,...
           'Position',[300,55,100,10]);
hcurrent_ear = uicontrol('Parent',f,'Style','slider','Position',[300,45,100,10],...
                'value', current_ear, 'min', 1, 'max', n_ears,...
                'Callback', @setear_Callback);
            
stage_text = sprintf('Set Stage - %d', current_stage);
hcurrent_stage_text  = uicontrol('Style','text','String',stage_text,...
           'Position',[300,30,50,10]);
hcurrent_stage = uicontrol('Parent',f,'Style','slider','Position',[300,20,100,10],...
                'value', current_stage, 'min', 1, 'max', n_stages,...
                'Callback', @setstage_Callback);
       
ha = axes('Units','pixels','Position',[50,60,200,185]);

align([hreaddata,hnaps,hdecimnaps,hagcstate,hpopup,hcurrent_ear_text,hcurrent_ear,hcurrent_stage_text,hcurrent_stage, hbm, hogc, hagc],'Center','None');

% Initialize the UI.
% Change units to normalized so components resize automatically.
f.Units = 'normalized';
ha.Units = 'normalized';
hreaddata.Units = 'normalized';
hnaps.Units = 'normalized';
hdecimnaps.Units = 'normalized';
hagcstate.Units = 'normalized';
htext.Units = 'normalized';
hpopup.Units = 'normalized';
hcurrent_ear.Units = 'normalized';
hcurrent_ear_text.Units = 'normalized';
hcurrent_stage.Units = 'normalized';
hcurrent_stage_text.Units = 'normalized';
hbm.Units = 'normalized';
hogc.Units = 'normalized';
hagc.Units = 'normalized';

% Generate the data to plot.

itd_offset = 22;  % about 1 ms

[signal, fs] = audioread('../test_data/binaural_test.wav');

test_signal = [signal((itd_offset+1):end), ...
               signal(1:(end-itd_offset))] / 10;
             
CF_c = CARFAC_Design(n_ears, fs);  % default design
CF_c = CARFAC_Init(CF_c);
[CF_c, decim_naps_c, naps_c, BM_c, ohc_c, agc_c, agc_state_c] = CARFAC_Run(CF_c, test_signal);

CF_o = CARFAC_Design(n_ears, fs);  % default design
CF_o = CARFAC_Init(CF_o);
[CF_o, decim_naps_o, naps_o, BM_o, ohc_o, agc_o, agc_state_o] = CARFAC_Run(CF_o, test_signal, 0, 1);

CF = CF_c; decim_naps = decim_naps_c; naps = naps_c; BM = BM_c; ohc = ohc_c; agc = agc_c; agc_state = agc_state_c;

surf(decim_naps(:, :, current_ear));
ylabel('Time Index');
xlabel('Frequency Channel');

% Assign a name to appear in the window title.
f.Name = 'CARFAC Visualize';

% Move the window to the center of the screen.
movegui(f,'center')

% Make the UI visible.
f.Visible = 'on';

%  Pop-up menu callback. Read the pop-up menu Value property to
%  determine which item is currently displayed and make it the
%  current data. This callback automatically has access to 
%  current_data because this function is nested at a lower level.
function popup_menu_Callback(source, ~) 
  % Determine the selected data set.
  str = source.String;
  val = source.Value;
  % Set current data to the selected data set.
  switch str{val}
  case 'Closed Loop' % User selects Peaks.
     open_loop = 0;
     CF = CF_c; decim_naps = decim_naps_c; naps = naps_c; BM = BM_c; ohc = ohc_c; agc = agc_c; agc_state = agc_state_c;
  case 'Open Loop' % User selects Membrane.
     open_loop = 1;
     CF = CF_o; decim_naps = decim_naps_o; naps = naps_o; BM = BM_o; ohc = ohc_o; agc = agc_o; agc_state = agc_state_o;
  end
end


function loaddata_Callback(~, ~, ~)
% Get the path to the audio file and read the audio file
    [filename, pathname] = uigetfile({'*.wav'}, 'Select File');
    if ~isempty(pathname)
        fullpathname = strcat (pathname, filename);
        [signal, fs] = audioread(fullpathname);
        test_signal = [signal((itd_offset+1):end), ...
               signal(1:(end-itd_offset))] / 10;

        CF_c = CARFAC_Design(n_ears, fs);  % default design
        CF_c = CARFAC_Init(CF_c);  % initializing the CF struct with zero states
        [CF_c, decim_naps_c, naps_c, BM_c, ohc_c, agc_c, agc_state_c] = CARFAC_Run(CF_c, test_signal);

        CF_o = CARFAC_Design(n_ears, fs);  % default design
        CF_o = CARFAC_Init(CF_o);
        [CF_o, decim_naps_o, naps_o, BM_o, ohc_o, agc_o, agc_state_o] = CARFAC_Run(CF_o, test_signal, 0, 1);

        if open_loop
            CF = CF_o; decim_naps = decim_naps_o; naps = naps_o; BM = BM_o; ohc = ohc_o; agc = agc_o; agc_state = agc_state_o;
        else
            CF = CF_c; decim_naps = decim_naps_c; naps = naps_c; BM = BM_c; ohc = ohc_c; agc = agc_c; agc_state = agc_state_c;
        end
    end
end

function napsbutton_Callback(~,~)
% Display surf plot of the currently selected data.
     surf(naps(:, :, current_ear));
     ylabel('Time Index');
     xlabel('Frequency Channel');
end

function decimnapsbutton_Callback(~,~) 
% Display mesh plot of the currently selected data.
     surf(decim_naps(:, :, current_ear));
     ylabel('Time Index');
     xlabel('Frequency Channel');
end

function agcstatebutton_Callback(~,~) 
% Display contour plot of the currently selected data.
    surf(agc_state(:, :, current_ear, current_stage));
    ylabel('Time Index');
    xlabel('Frequency Channel');
end

function bmbutton_Callback(~,~) 
% Display contour plot of the currently selected data.
    surf(BM(:, :, current_ear));
    ylabel('Time Index');
    xlabel('Frequency Channel');
end

function ohcbutton_Callback(~,~) 
% Display contour plot of the currently selected data.
    surf(ohc(:, :, current_ear));
    ylabel('Time Index');
    xlabel('Frequency Channel');
end

function agcbutton_Callback(~,~) 
% Display contour plot of the currently selected data.
    surf(agc(:, :, current_ear));
    ylabel('Time Index');
    xlabel('Frequency Channel');
end

function setear_Callback(es, ~)
    current_ear = uint8(es.Value);
    ear_text = sprintf('Set Ear - %d', current_ear);
    set(hcurrent_ear_text, 'String', ear_text);
end

function setstage_Callback(es, ~)
    current_stage = uint8(es.Value);
    stage_text = sprintf('Set Stage - %d', current_stage);
    set(hcurrent_stage_text, 'String', stage_text);
end

end