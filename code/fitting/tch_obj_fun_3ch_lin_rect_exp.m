function obj_fun = tch_obj_fun_3ch_lin_rect_exp(roi, model)
% Generates anonymous objective function that can be passed to fmincon for
% the 3ch-lin-rect-exp model (3-channel model with linear sustained, 
% rectified transient, and exponential delay channels).
% 
% INPUTS:
%   1) roi: tchROI object containing single session
%   2) model: tchModel object for the same session
% 
% OUTPUTS:
%   obj_fun: anonymous objective function in the form of y = f(x0), where
%   x0 is a vector of parameters to evaluate and y is the sum of squared
%   residual error between model predictions and run response time series
% 
% AS 10/2017

if ~strcmp(model.type, '3ch-lin-rect-exp'); error('Incompatible model type'); end
stim = model.stim; nruns = size(stim, 1); irfs = model.irfs; fs = model.fs;
run_avgs = roi.run_avgs; baseline = roi.baseline; tr = roi.tr;

delay_fun = @(y) exp(-(1:12000) / (y * 1000));
conv_snS = @(x) cellfun(@(X) convolve_vecs(X, irfs.nrfS{1}, 1, 1), ...
    x, 'uni', false);
conv_snT = @(x) cellfun(@(X) rectify(convolve_vecs(X, irfs.nrfT{1}, 1, 1), 'positive'), ...
    x, 'uni', false);
doffsets = cellfun(@(X, Y) [X(2:end) Y], model.onsets, model.run_durs, 'uni', false);
conv_snD = @(x, y) cellfun(@(X, Y, ON, OFF) code_exp_decay(X, ON, OFF, Y, fs), ...
    cellfun(@code_delay_act, x, 'uni', false), repmat({delay_fun(y)}, nruns, 1), ...
    model.offsets, doffsets, 'uni', false);
conv_nbS = @(x) cellfun(@(NS) convolve_vecs(NS, irfs.hrf{1}, fs, 1 / tr), ...
    conv_snS(x), 'uni', false);
conv_nbT = @(x) cellfun(@(NT) convolve_vecs(NT, irfs.hrf{1}, fs, 1 / tr), ...
    conv_snT(x), 'uni', false);
conv_nbD = @(x, y) cellfun(@(ND) convolve_vecs(ND, irfs.hrf{1}, fs, 1 / tr), ...
    conv_snD(x, y), 'uni', false);
conv_nb = @(x, y) cellfun(@(S, T, D) [S T D], ...
    conv_nbS(x), conv_nbT(x), conv_nbD(x, y), 'uni', false);
comp_bs = @(m, b0) cellfun(@(M, B0) M - repmat(B0, size(M, 1), 1), ...
    m, b0, 'uni', false);
comp_ws = @(x, y, m, b0) cell2mat(conv_nb(x, y)) \ cell2mat(comp_bs(m, b0));
pred_bs = @(x, y, m, b0) cellfun(@(P, W) P .* repmat(W, size(P, 1), 1), ...
    conv_nb(x, y), repmat({comp_ws(x, y, m, b0)'}, nruns, 1), 'uni', false);
calc_br = @(x, y, m, b0) cellfun(@(S, M) (sum(S, 2) - M) .^ 2, ...
    pred_bs(x, y, m, b0), comp_bs(m, b0), 'uni', false);
calc_me = @(x, y, m, b0) sum(cell2mat(calc_br(x, y, m, b0)));
obj_fun = @(x) calc_me(stim, x(1), run_avgs, baseline);

end