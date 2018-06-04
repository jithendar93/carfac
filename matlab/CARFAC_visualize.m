% Visualizing CARFAC, matlab stuff

clear variables;

n_ears = 2;
agc_plot_fig_num = 1;

tic

[signal, fs] = audioread('/Data/Dropbox/Datasets/audio_samples/timit_sample_LDC93S1.wav');

itd_offset = 22;  % about 1 ms
test_signal = [signal((itd_offset+1):end), ...
               signal(1:(end-itd_offset))] / 10;
             
CF_struct = CARFAC_Design(n_ears, fs);  % default design

% Run stereo test:

CF_struct = CARFAC_Init(CF_struct);

[CF_struct, nap_decim, nap] = CARFAC_Run(CF_struct, test_signal, agc_plot_fig_num);

% Display results for 2 ears:
for ear = 1:n_ears
  smooth_nap = nap_decim(:, :, ear);
  figure(ear + n_ears)  % Makes figures 3 and 4
  image(63 * (abs(smooth_nap)' .^ 0.5))

  colormap(1 - gray);
end

toc

% Show resulting data, even though M-Lint complains:
CF_struct
CF_struct.ears(1).CAR_state
CF_struct.ears(1).AGC_state
min_max = [min(nap(:)), max(nap(:))]
min_max_decim = [min(nap_decim(:)), max(nap_decim(:))]