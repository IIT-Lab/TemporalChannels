function model = pred_trials_3ch_opt(model)
% Generates trial predictors using an optimized 3-channel model.

% get design parameters
sessions = model.sessions; nsess = length(sessions);
params = model.params; irfs = model.irfs;
fs = model.fs; tr = model.tr; cond_list = model.cond_list;
stimfiles = model.stimfiles; nruns = model.num_runs;
model.trial_preds.S = cell(max(cellfun(@length, cond_list)), nsess, model.num_exps);
model.trial_preds.T = cell(max(cellfun(@length, cond_list)), nsess, model.num_exps);
model.trial_preds.D = cell(max(cellfun(@length, cond_list)), nsess, model.num_exps);

rcnt = 1;
for ee = 1:model.num_exps
    [on, off, c, ims, ton, toff, tc, rd, cl] = tch_stimfile(stimfiles{rcnt, 1});
    istim = model.stim{rcnt, 1};
    for cc = 1:length(cond_list{ee})
        % find trial onset and offset times
        ii = find(strcmp(cl{cc}, tc), 1);
        ion = ton(ii); ioff = ceil(toff(ii) - .001); td = ioff - ion;
        % extract stimulus vector from condition time window
        cstim = istim(fs * (ion - model.pre_dur) + 1:round(fs * (ion + td + model.post_dur)), :);
        cstim(1:fs * model.pre_dur, :) = 0;
        cstim(fs * (model.pre_dur + td):size(cstim, 1), :) = 0;
        for ss = 1:length(sessions)
            % convolve stimulus with channel IRFs
            predS = convolve_vecs(cstim, irfs.nrfS{ss}, fs, fs);
            predT = convolve_vecs(cstim, irfs.nrfT{ss}, fs, fs);
            predTr = rectify(predT);
            predD = convolve_vecs(cstim, irfs.nrfD{ss}, fs, fs);
            predDr = rectify(predD, 'negative') .^ 2;
            % convolve neural predictors with HRF
            fmriS = convolve_vecs(predS, irfs.hrf{ss}, fs, 1 / tr);
            fmriT = convolve_vecs(predTr, irfs.hrf{ss}, fs, 1 / tr);
            fmriD = convolve_vecs(predDr, irfs.hrf{ss}, fs, 1 / tr);
            % store fMRI predictors in model structure
            model.trial_preds.S{cc, ss, ee} = fmriS;
            model.trial_preds.T{cc, ss, ee} = fmriT * model.normT;
            model.trial_preds.D{cc, ss, ee} = fmriD * model.normD;
        end
    end
    rcnt = rcnt + nruns(ee, 1);
end

end
