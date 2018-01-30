function model = pred_runs_3ch_cexp_quad_exp(model)
% Generates run predictors using the 3 temporal-channel model with
% compressed/adapted sustained, quradratic transient, and optimized persistent
% channel.

% get design parameters
fs = model.fs; tr = model.tr; stim = model.stim;
nruns_max = size(stim, 1); empty_cells = cellfun(@isempty, stim);
params_names = fieldnames(model.params); params = [];
for pp = 1:length(params_names)
    pname = model.params.(params_names{pp});
    params.(params_names{pp}) = repmat(pname, nruns_max, 1);
end
irfs_names = fieldnames(model.irfs); irfs = [];
for ff = 1:length(irfs_names)
    iname = model.irfs.(irfs_names{ff});
    irfs.(irfs_names{ff}) = repmat(iname, nruns_max, 1);
end

% generate run predictors for each session
predTq = cellfun(@(X, Y) convolve_vecs(X, Y, fs, fs) .^ 2, ...
    stim, irfs.nrfT, 'uni', false); predTq(empty_cells) = {1};
fmriS = cellfun(@(X, Y) convolve_vecs(X, Y, fs, 1 / tr), ...
    model.adapt_act, irfs.hrf, 'uni', false); fmriS(empty_cells) = {[]};
fmriT = cellfun(@(X, Y) convolve_vecs(X, Y, fs, 1 / tr), ...
    predTq, irfs.hrf, 'uni', false); fmriT(empty_cells) = {[]};
fmriP = cellfun(@(X, Y) convolve_vecs(X, Y, fs, 1 / tr), ...
    model.persist_act, irfs.hrf, 'uni', false); fmriP(empty_cells) = {[]};
run_preds = cellfun(@(X, Y, Z) [X Y * model.normT Z * model.normP], ...
    fmriS, fmriT, fmriP, 'uni', false); run_preds(empty_cells) = {[]};
model.run_preds = run_preds;

end
