function model = pred_trials_3ch_cexp_quad_exp(model)
% Generates trial predictors using a 3 temporal-channel model with 
% compressed/adapted sustained, quadratic transient, and optimized delay 
% channel. 

% get design parameters
sessions = model.sessions; nsess = length(sessions); irfs = model.irfs;
cond_list = model.cond_list; nconds_max = max(cellfun(@length, cond_list));
stimfiles = model.stimfiles; nruns = model.num_runs;
fs = model.fs; tr = model.tr; nexps = model.num_exps; rcnt = 1;
model.trial_preds.S = cell(nconds_max, nsess, nexps);
model.trial_preds.T = cell(nconds_max, nsess, nexps);
model.trial_preds.D = cell(nconds_max, nsess, nexps);

for ee = 1:nexps
    [~, ~, ~, ~, ton, toff, tc, ~, cl] = tch_stimfile(stimfiles{rcnt, 1});
    for cc = 1:length(cond_list{ee})
        % find trial onset and offset times and calculate duration
        idx = find(strcmp(cl{cc}, tc), 1);
        td = ceil(toff(idx) - .001) - ton(idx);
        % extract stimulus vector from condition time window
        cstim_start = round(fs * (ton(idx) - model.pre_dur)) + 1;
        cstim_stop = round(fs * (ton(idx) + td + model.post_dur));
        cstim = model.stim{rcnt, 1}(cstim_start:cstim_stop, :);
        dcstim = diff(sum(cstim, 2)); cdelay = code_delay_act(cstim);
        starts = find(dcstim == 1) / fs; stops = find(dcstim == -1) / fs;
        dstarts = stops; dstops = starts; dstops(1) = [];
        dstops = [dstops; size(cstim, 1) / fs];
        for ss = 1:length(sessions)
            % convolve stimulus with channel IRFs
            predS = convolve_vecs(cstim, irfs.nrfS{ss}, fs, fs);
            adapt_exp = model.irfs.adapt_exp{ss};
            adapt_act = code_exp_decay(predS, starts, stops, adapt_exp, fs);
            predTq = convolve_vecs(cstim, irfs.nrfT{ss}, fs, fs) .^ 2;
            delay_exp = model.irfs.delay_exp{ss};
            delay_act = code_exp_decay(cdelay, dstarts, dstops, delay_exp, fs);
            % convolve neural predictors with HRF
            fmriS = convolve_vecs(adapt_act, irfs.hrf{ss}, fs, 1 / tr);
            fmriT = convolve_vecs(predTq, irfs.hrf{ss}, fs, 1 / tr);
            fmriD = convolve_vecs(delay_act, irfs.hrf{ss}, fs, 1 / tr);
            % store fMRI predictors in model structure
            model.trial_preds.S{cc, ss, ee} = fmriS;
            model.trial_preds.T{cc, ss, ee} = fmriT * model.normT;
            model.trial_preds.D{cc, ss, ee} = fmriD * model.normD;
        end
    end
    rcnt = rcnt + nruns(ee, 1);
end

end