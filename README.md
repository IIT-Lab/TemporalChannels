# TemporalChannels
Code for modeling fMRI responses to time-varying stimuli using a temporal channels approach
* * *
*Notes:*
- The code in this repository is compatible with [MATLAB](https://www.mathworks.com) R2015a and later versions. 
- An example dataset is available [here](http://vpnl.stanford.edu/TemporalChannels/TemporalChannels_data.tar.gz) (archive is **20 GB**). 
* * *
*Contents:*
1. [Instructions](#instructions)
    1. [Oranizing the data directory](#organizing-the-data-directory)
    2. [Generating stimulus timing parameter files](#generating-stimulus-timing-parameter-files)
    3. [Modeling a region of interest using model_roi](#modeling-a-region-of-interest-using-model_roi)
        1. [Inputs](#inputs)
        2. [Outputs](#outputs)
    4. [Modeling each voxel using model_vox](#modeling-each-voxel-using-model_vox)
        1. [Inputs](#inputs)
        2. [Outputs](#outputs)
2. [Example code](#example-code)
    1. [Using the model_roi function](#using-the-model_roi-function)
    2. [Using ModelTS class methods](#using-modelts-class-methods)
    3. [Using ROI class methods](#using-roi-class-methods)
    4. [Using Voxel class methods](#using-voxel-class-methods)
* * *
## Instructions
 
### Organizing the data directory
 
To work with the example dataset, download the [archive](http://vpnl.stanford.edu/TemporalChannels/TemporalChannels_data.tar.gz) and extract all session directories in `~/TemporalChannels/data/` of your local branch of the repository. 
 
To work with your own dataset, create a separate directory for each experimental session in  `~/TemporalChannels/data/`. Here, a *session* is an fMRI scan session for a single participant typically comprised of a series of runs acquired with the same scan settings (slice prescription, voxel size, etc.) such that a participant can have multiple scan sessions (e.g., on different days). 
 
Each session directory should contain the following subdirectories: 
 
1. *ROIs* – contains `.mat` files sorted by region name/experiment and labeled by run number (e.g., `~/TemporalChannels/data/*/ROIs/V1/Exp1/Run1.mat`). Each file contains the raw fMRI time series of each voxel in a predefined region of interest for a single run. Each run of data is formatted as a matrix `tSeries` with rows indexing TRs (sorted in ascending order) and columns indexing voxels (sorted in arbitrary order). This data is used for fitting models to the mean response of all voxels in a region and performing group analysis across all sessions with that region. To calcualte group statistics, it is necessary for region and experiment directory names to match across sessions. 
 
2. *Voxels* – contains `.mat` files sorted by experiment and labeled by run number (e.g., `~/TemporalChannels/data/*/Voxels/Exp1/Run1.mat`) that contain the raw fMRI time series of each voxel in a scan session for a single run. Each run of data is formatted as a matrix `tSeries` with rows indexing TRs (sorted in ascending order) and columns indexing a voxels (sorted in arbitrary order). This data is used for fitting models to the response of each voxel in a fMRI session. The results of this voxel-level analysis can be adapted for various subsequent analyses (e.g., generating model parameter maps or performing multi-voxel pattern analysis).
 
3. *Stimuli* – contains `.txt` files labeled by experiment and run number that list information about the timing of each stimulus in a single run of an experiment. The names of experiments in the filenames must match the names of folders in the session *ROIs* and *Voxels* directories and are delimited from run numbers by an underscore (e.g., `~/TemporalChannels/data/*/Stimuli/Exp1_Run1.txt`).
 
### Generating stimulus timing parameter files
 
Example stimulus timing parameter files are available in [`~/fLoc/examples/`](https://github.com/VPNL/TemporalChannels/tree/master/examples).
 
- Experiment with long stimulus presentations: [Exp1_Run1.txt](https://github.com/VPNL/TemporalChannels/tree/master/examples/Exp1_Run1.txt)
- Experiment with short stimulus presentations: [Exp2_Run1.txt](https://github.com/VPNL/TemporalChannels/tree/master/examples/Exp2_Run1.txt)
- Experiment with varied presentation durations: [Exp3_Run1.txt](https://github.com/VPNL/TemporalChannels/tree/master/examples/Exp3_Run1.txt)
 
#### Header information
 
Line 1 contains the name of the experiment followed by a list of all conditions (i.e, trial types). For example:
```
Exp1 conditions: TrialA, TrialB, TrialC, TrialD
```
 
Line 2 contains the total duration of the run in seconds. For example: 
```
Run duration (s): 300
```
 
Here, experiments and trials are used to refer to specific groupings or segments of data from a fMRI session:
 
- *Experiments* are collections of runs composed of the same set of trial types that are repeated across sessions. To assess the test-retest reliability of the data, different "experiments" could also contain different splits of the data from a common set of stimulus conditions. 
 
- *Trials* are structured periods of stimulus presentation within a run that are separated by baseline periods (ideally ≥ 12 s). Baseline conditions mark transitions between different trials that repeat throughout the experiment and across sessions.
 
The overall duration and number of stimuli in a trial can vary across trial types, but the timing and sequence of stimulus presentations must be identical across trials of the same type. Critically, trial segmentation does not affect the fit of the model but does affect noise ceiling estimation and visualization methods.
 
#### Stimulus information
 
Lines 5 and below contain the following information about each stimulus delimited by spaces:
 
1. *Trial* — trial **number** incrementing from 1 to the total number of trials in the run.
 
2. *Condition* — label indicating the **type** of trial to which the stimulus belongs (same as in line 1).
 
3. *Onset* — stimulus onset time in **seconds** relative to the beginning of the run.
 
4. *Duration* — stimulus presentation duration in **seconds**.
 
5. *Filename* — stimulus descriptor composed of a **label** and stimulus-specific **identifier** delimited by a dash (e.g., `face-1.jpg`). Note that a separate array of predictors is coded for each unique label.
 
There is no need to model the baseline explicitly. That is, the code assumes a baseline condition for all times in which a stimulus is not shown. We recommend including a prolonged (≥ 12 s) baseline period immediately before each trial to use the trial averaging code and associated plotting functions.
 
### Modeling a region of interest using model_roi
 
The `model_roi` wrapper function is used to fit and validate various temporal models to the mean time series of a region of interest in each session using the procedures described below:
 
1. An object `roi` of the class `ROI` is generated that loads, preprocesses, and organizes the run time series for a set of experiments in each session. As explained in detail below `roi(1)` is an object containing model fits, and `roi(2)` is an object containing validation of those fits.
    1. Run time series averaged across all voxels in a region are stored in a 2D cell array `roi(1).run_avgs` with each row indexing a run and each column indexing a session (e.g., `roi(1).run_avgs(N, :)` contains all runs from the *N*-th session in the object).
    2. Storing time series in a cell array allows the code to accommodate runs with different durations as well as sessions with different numbers of runs.
 
2. An object `model` of the class `ModelTS` is generated that creates channel predictors for a set of experiments in each session, where `model(1)` contains channel predictors for the data used to fit the model and `model(2)` contains channel predictors for the independent validation data. The channel predictors are derived from the stimulus sequence and the model architecture.
    1. Run predictors are stored in a 2D cell array `model(1).run_preds` with each row indexing a run and each column indexing a session (e.g., `model(1).run_preds(N, :)` contains all run predictors for the *N*-th session in the object). 
    2. Predictors are also generated for each trial type and stored in a 3D cell array `model(1).trial_preds` with each row indexing a trial type, each column indexing a session, and each slice indexing an experiment (e.g., `model(1).trial_preds(:, N, K)` contains predictors for each trial type in the *K*-th experiment of the *N*-th session). Be aware that trial predictors will vary across sessions for models with session-specific hyperparameters such as the CTS model.
 
3. Response amplitudes (*β* weights) for each predictor in the model are estimated separately for each session using a general linear model (GLM).
    1. Fitted *β* weights for each predictor are stored in a 1D cell array `roi(1).model.betas` with each cell containing the model solution for an individual session (e.g., `roi(1).model.betas(N)` contains the *β* weights for the *N*-th session). For multi-channel models, weights are organized such that *β*s from the sustained channel are indexed before *β*s from the transient channel.
    2. Model performance (*R*^2) is calculated across all experiments and stored in a 1D cell array `roi(1).model.varexp` with each cell indexing model performance for a single session (e.g., `roi(1).model.varexp(N)` contains *R*^2 for the *N*-th session).
 
4. Fitted β weights are used to predict responses to each trial type.
    1. The average response to each trial type is stored in a 3D cell array `roi(1).trial_avgs` with each row indexing a trial type, each column indexing a session, and each slice indexing an experiment (e.g., `roi(1).trial_avgs(:, N, K)` contains the average response to each trial type in the *K*-th experiment of the *N*-th session).
    2. The predicted fMRI response to each trial type is stored in a 3D cell array `roi(1).pred` with each row indexing a trial type, each column indexing a session, and each slice indexing an experiment (e.g., `roi(1).pred(:, N, K)` contains the predicted response to each trial type in the *K*-th experiment of the *N*-th session).
 
5. Model validation is performed using the fitted *β* weights to predict responses in independent data.
    1. *β* weights fitted to independent data are stored in a 1D cell array `roi(2).model.betas` with each cell containing the model solution for an individual session (e.g., `roi(2).model.betas(N)` contains the *β* weights for the *N*-th session fitted to data in `roi(1)`).
    2. Model performance (*R*^2) is calculated for each session across all experiments in the validation data and stored in a 1D cell array `roi(2).model.varexp` with each cell indexing validation performance for a single session (e.g., `roi(2).model.varexp(N)` contains validated *R*^2 for the *N*-th session).
 
#### Inputs
 
Fitting a model using the `model_roi` function requires passing at least three input arguments:
 
1. *name* — name of a region of interest (e.g., `'V1'`) in session ROI directories (`~/TemporalChannels/data/*/ROIs/`).
 
2. *type* — label indicating which model to use for predicting responses.
    1. `‘standard’` — standard linear systems analysis of fMRI data (Boynton et al., 1996)
    2. `‘htd’` — hemodynamic temporal derivative model (Henson et al., 2002)
    3. `‘cts-pow’` — compressive temporal summation model with power law (Zhou et al., 2017)
    4. `‘cts-div’` — compressive temporal summation model with divisive normalization (Zhou et al., 2017)
    5. `‘2ch’` — 2 temporal-channel model (Stigliani et al., 2017)
 
3. *fit_exps* — which experiment/s to use for fitting the model (e.g., `{'Exp1' 'Exp2'}`) with experiment names matching the stems of filenames in the session Stimuli directories (`~/TemporalChannels/data/*/Stimuli/`).
 
4. *val_exps* — optional argument specifying which experiment/s to use for validating the model (e.g., `'Exp3'`).
 
#### Outputs
 
After fitting a model to data from each session, the function plots the session-averaged measured vs. predicted fMRI responses for each trial type and returns two outputs:
 
1. *roi* — object of the class `ROI` that stores fMRI data and model predictions for a given region of interest.
    1. `roi(1).run_avgs` — contains average time series for each run in *fit_exps* (see `roi(2).run_avgs` for *val_exps* if applicable)
    2. `roi(1).trial_avgs` —  contains average time series for each trial type in *fit_exps* (see `roi(2).trial_avgs` for *val_exps*)
    3. `roi(1).model` — contains model fits and *R*^2 (see `roi(2).model` for *val_exps*)
    4. See properties in `ROI` class file for more details ([`~/TemporalChannels/functions/ROI.m`](https://github.com/VPNL/TemporalChannels/blob/master/code/ROI.m))
 
2. *model* — object of the class `ModelTS` that stores channel predictors for each session.
    1. `model(1).run_preds` — contains predictors for each run in *fit_exps* (see `model(2).run_preds` for *val_exps* if applicable)
    2. `model(1).trial_preds` — contains predictors for each trial type in *fit_exps* that are used for visualization (see `model(2).trial_preds` for *val_exps*)
    3. `model(1).irfs` — stores impulse response functions
    4. `model(1).params` — stores model hyperparameters
    5. See properties in `ModelTS` class file for more details ([`~/TemporalChannels/functions/ModelTS.m`](https://github.com/VPNL/TemporalChannels/blob/master/code/ModelTS.m))
 
By default, both outputs are saved in a `.mat` file in the results directory (`~/TemporalChannels/results/`).
 
### Modeling each voxel using model_vox
 
The `model_vox` wrapper function can be used to fit a model in each voxel using the procedure described below:
 
1. An object `vox` of the class `Voxel` is generated that loads, preprocess, and organizes the run time series of each voxel for a set of experiments in each session. 
    1. Run time series for each voxel are stored in a 2D cell array `vox(1).runs` with each row indexing a run and each column indexing a session (e.g., `vox(1).runs(K, N)` contains a TR by voxel time series matrix from the *K*-th run of the *N*-th session in the object).
    2. Make note of the reshape parameters you used flatten the fMRI volumes in `~/TemporalChannels/data/*/Voxels` so you can perform the inverse transformation to reshape the model parameter vectors back to volume space for subsequent analyses. 
 
2. An object `model` of the class `ModelTS` is generated that creates channel predictors for a set of experiments in each session, where `model(1)` contains channel predictors for the data used to fit the model and `model(2)` contains channel predictors for the independent validation data. The channel predictors are derived from the stimulus sequence and the model architecture.
    1. Run predictors are stored in a 2D cell array `model(1).run_preds` with each row indexing a run and each column indexing a session (e.g., `model(1).run_preds(N, :)` contains all run predictors for the *N*-th session in the object). 
    2. Predictors are also generated for each trial type and stored in a 3D cell array `model(1).trial_preds` with each row indexing a trial type, each column indexing a session, and each slice indexing an experiment (e.g., `model(1).trial_preds(:, N, K)` contains predictors for each trial type in the *K*-th experiment of the *N*-th session). Be aware that trial predictors will vary across sessions for models with session-specific hyperparameters such as the CTS model.
   
3. Response amplitudes (β weights) for each predictor are estimated in each voxel using a GLM.
    1. Fitted *β* weights for each predictor are stored in a 1D cell array `vox(1).model.betas` with each cell containing the model solutions for all voxels in a session (e.g., `vox(1).model.betas(N)` contains the *β* weights for each voxel in the *N*-th session). For multi-channel models, the weights are organized such that *β*s from the sustained channel are indexed before *β*s from the transient channel.
    2. Model performance (*R*^2) is calculated in each voxel across all experiments and stored in a 1D cell array `vox(1).model.varexp` with each cell indexing model performance for a single session (e.g., `vox(1).model.varexp(N)` contains *R*^2 for each voxel in the *N*-th session).
 
4. Model validation is performed using the fitted β weights for each voxel to predict responses in independent data.
    1. *β* weights fitted to independent data are stored in a 1D cell array `vox(2).model.betas` with each cell containing the model solutions for all voxels in an individual session (e.g., `vox(2).model.betas(N)` contains the *β* weights for the *N*-th session fitted to data in `vox(1)`).
    2. Model performance (*R*^2) is calculated in each voxel across all experiments in the validation set and stored in a 1D cell array `vox(2).model.varexp` with each cell indexing validation performance for a single session (e.g., `vox(2).model.varexp(N)` contains validated *R*^2 for each voxel the *N*-th session).
 
#### Inputs
 
Fitting models to each voxel using the `model_vox` function requires passing at least two input arguments:
 
1. *type* — label indicating which model to use for predicting responses.
    1. `‘standard’` — standard linear systems analysis of fMRI data (Boynton et al., 1996)
    2. `‘htd’` — hemodynamic temporal derivative model (Henson et al., 2002)
    3. `‘cts-pow’` — compressive temporal summation model with power law (Zhou et al., 2017)
    4. `‘cts-div’` — compressive temporal summation model with divisive normalization (Zhou et al., 2017)
    5. `‘2ch’` — 2 temporal-channel model (Stigliani et al., 2017)
 
2. *fit_exps* — which experiment/s to use for fitting the model (e.g., `{'Exp1' 'Exp2'}`) with experiment names matching the stems of filenames in the session Stimuli directories (`~/TemporalChannels/data/*/Stimuli/`).
 
3. *val_exps* — optional argument specifying which experiment/s to use for validating the model (e.g., `'Exp3'`).
 
#### Outputs
 
After fitting the model in each voxel, the function returns two outputs:
 
1. *vox* — object of the class `Voxel` that stores fMRI data and model parameters for each voxel.
    1. `vox(1).runs` — contains run time series for *fit_exps* (see `vox(2).runs` for *val_exps* if applicable)
    2. `vox(1).trials` —  contains trial time series for *fit_exps* (see `vox(2).trials` for *val_exps*)
    3. `vox(1).model` — contains model fits and *R*^2 (see `vox(2).model` for *val_exps*)
    4. See properties in `Voxel.m` class file for more details ([`~/TemporalChannels/functions/Voxel.m`](https://github.com/VPNL/TemporalChannels/blob/master/code/Voxel.m))
2. *model* — object of the class `ModelTS` that stores channel predictors for each session.
    1. `model(1).run_preds` — contains predictors for each run in *fit_exps* (see `model(2).run_preds` for *val_exps* if applicable)
    2. `model(1).trial_preds` — contains predictors for each trial type in *fit_exps* that are used for visualization (see `model(2).trial_preds` for *val_exps*)
    3. `model(1).irfs` — stores impulse response functions
    4. `model(1).params` — stores model hyperparameters
    5. See properties in `ModelTS` class file for more details ([`~/TemporalChannels/functions/ModelTS.m`](https://github.com/VPNL/TemporalChannels/blob/master/code/ModelTS.m))
 
By default, outputs are saved in the results directory (`~/TemporalChannels/results/`). To generate whole-brain maps of model parameters, you must apply the inverse of the transformation used to flatten the volumetric data stored in `~/TemporalChannels/data/*/Voxels/`.
 
## Example code
 
### Using the model_roi function
 
Example of fitting the 2 temporal-channel model using V1 data from Exp1 & Exp2:
 
    [roi, model] = model_roi(‘V1', '2ch', {‘Exp1’ 'Exp2'});
 
Example of fitting the standard model using V1 data from Exp1 & Exp2 and validating on V1 data from Exp3:
 
    [roi, model] = model_roi(‘V1', 'standard', {‘Exp1’ 'Exp2'}, 'Exp3');
 
### Using ModelTS class methods
 
The `ModelTS.m` class file defines a class of objects that store predictors for each run and trial type using the methods listed in the example below.
 
Example of creating predictors using a ModelTS object (`model`):
 
    type = '2ch';                              % specify the type of model to use
    fit_exps = {'Exp1' 'Exp2'};                % list of experiments for fitting
    sessions = roi.sessions;                   % list of sessions to model (see below)
    model = ModelTS(type, fit_exps, sessions); % setup ModelTS object
    model = code_stim(model);                  % code the timing of stimuli
    model = pred_runs(model);                  % generate channel predictors
    model = pred_trials(model);                % generate trial predictors
 
### Using ROI class methods
 
The `ROI.m` class file defines a class of objects that store and operate on fMRI time series for a given region of interest using the methods listed in the example below.
 
Example of fitting a model to a ROI object (`roi`):
 
    roi_name = 'V1';               % name of region to model
    fit_exps = {'Exp1' 'Exp2'};    % list of experiments for fitting
    roi = ROI(roi_name, fit_exps); % setup ROI object
    roi = tc_runs(roi);            % preprocess run time series
    roi = tc_trials(roi, model);   % compile responses to each trial
    roi = tc_noise_ceil(roi);      % estimate noise ceiling for each region
    roi = tc_fit(roi, model);      % fit model for each session
    roi = tc_pred(roi, model);     % predict responses for each trial type
 
Plot mean response across all sessions for each trial type in experiments:
 
    fig = plot_exps(roi);
 
Plot mean response vs. model prediction across all sessions for each trial type:
 
    fig = plot_model(roi);
 
Plot response vs. model prediction in individual sessions for each run:
 
    fig = plot_runs(roi);
 
### Using Voxel class methods
 
The `Voxel.m` class file defines a class of objects that store and operate on fMRI time series in each voxel using the methods listed in the example below.
 
Example of fitting a model to a Voxel object (`vox`):
 
    fit_exps = {'Exp1' 'Exp2'};  % list of experiments for fitting
    vox = Voxel(fit_exps);       % setup Voxel object for all sessions
    vox = tc_runs(vox);          % preprocess run time series
    vox = tc_trials(vox, model); % compile responses to each trial
    vox = tc_fit(vox, model);    % fit model for each voxel
 