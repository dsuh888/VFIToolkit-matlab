function [p_eqm,p_eqm_index,GeneralEqmConditions]=HeteroAgentStationaryEqm_Case1_FHorz(jequaloneDist,AgeWeightParamNames, n_d, n_a, n_z, N_j, n_p, pi_z, d_grid, a_grid, z_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Parameters, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames,heteroagentoptions, simoptions, vfoptions)
% If n_p=0 then will use fminsearch to find the general equilibrium (find
% price vector that corresponds to GeneralEqmConditions=0). By setting n_p to
% nonzero it is assumed you want to use a grid on prices, which must then
% be passed in using heteroagentoptions.p_grid

% N_d=prod(n_d);
% N_a=prod(n_a);
N_z=prod(n_z);
N_p=prod(n_p);

l_p=length(GEPriceParamNames); % Otherwise get problem when not using p_grid
%l_p=length(n_p);

p_eqm_vec=nan; p_eqm_index=nan; GeneralEqmConditions=nan;

%% Check which options have been used, set all others to defaults 
if exist('vfoptions','var')==0
    vfoptions.parallel=1+(gpuDeviceCount>0);
    %If vfoptions is not given, just use all the defaults
    %Note that the defaults will be set when we call 'ValueFnIter...'
    %commands and the like, so no need to set them here except for a few.
else
    %Check vfoptions for missing fields, if there are some fill them with the defaults
    if isfield(vfoptions,'parallel')==0
        vfoptions.parallel=1+(gpuDeviceCount>0);
    end
end

if exist('simoptions','var')==0
    simoptions=struct(); % create a 'placeholder' simoptions that can be passed to subcodes
end

if exist('heteroagentoptions','var')==0
    heteroagentoptions.multiGEcriterion=1;
    heteroagentoptions.multiGEweights=ones(1,length(GeneralEqmEqns));
    heteroagentoptions.toleranceGEprices=10^(-4); % Accuracy of general eqm prices
    heteroagentoptions.toleranceGEcondns=10^(-4); % Accuracy of general eqm eqns
    heteroagentoptions.fminalgo=1;
    heteroagentoptions.verbose=0;
    heteroagentoptions.maxiter=1000;
else
    if isfield(heteroagentoptions,'multiGEcriterion')==0
        heteroagentoptions.multiGEcriterion=1;
    end
    if isfield(heteroagentoptions,'multiGEweights')==0
        heteroagentoptions.multiGEweights=ones(1,length(GeneralEqmEqns));
    end
    if N_p~=0
        if isfield(heteroagentoptions,'pgrid')==0
            disp('VFI Toolkit ERROR: you have set n_p to a non-zero value, but not declared heteroagentoptions.pgrid')
        end
    end
    if isfield(heteroagentoptions,'toleranceGEprices')==0
        heteroagentoptions.toleranceGEprices=10^(-4); % Accuracy of general eqm prices
    end
    if isfield(heteroagentoptions,'toleranceGEcondns')==0
        heteroagentoptions.toleranceGEcondns=10^(-4); % Accuracy of general eqm prices
    end
    if isfield(heteroagentoptions,'verbose')==0
        heteroagentoptions.verbose=0;
    end
    if isfield(heteroagentoptions,'fminalgo')==0
        heteroagentoptions.fminalgo=1; % use fminsearch
    end
    if isfield(heteroagentoptions,'maxiter')==0
        heteroagentoptions.maxiter=1000; % use fminsearch
    end
end

%%
% If 'exogenous shock fn' is used, then precompute it to save evaluating it numerous times
% Check if using 'exogenous shock fn' (exogenous state has a grid and transition matrix that depends on age)
if isfield(vfoptions,'pi_z_J')
    % Do nothing, this is just to avoid doing the next 'elseif' statement
elseif isfield(vfoptions,'ExogShockFn')
    overlap=0;
    for ii=1:length(vfoptions.ExogShockFnParamNames)
        if strcmp(vfoptions.ExogShockFnParamNames{ii},GEPriceParamNames)
            overlap=1;
        end
    end
    if overlap==0
        % If ExogShockFn does not depend on any of the GEPriceParamNames, then
        % we can simply create it now rather than within each 'subfn' or 'p_grid'
        pi_z_J=zeros(N_z,N_z,N_j);
        z_grid_J=zeros(sum(n_z),N_j);
        for jj=1:N_j
            if isfield(vfoptions,'ExogShockFnParamNames')
                ExogShockFnParamsVec=CreateVectorFromParams(Parameters, simoptions.ExogShockFnParamNames,jj);
                ExogShockFnParamsCell=cell(length(ExogShockFnParamsVec),1);
                for ii=1:length(ExogShockFnParamsVec)
                    ExogShockFnParamsCell(ii,1)={ExogShockFnParamsVec(ii)};
                end
                [z_grid,pi_z]=simoptions.ExogShockFn(ExogShockFnParamsCell{:});
            else
                [z_grid,pi_z]=simoptions.ExogShockFn(jj);
            end
            pi_z_J(:,:,jj)=gather(pi_z);
            z_grid_J(:,jj)=gather(z_grid);
        end
        % Now store them in vfoptions and simoptions
        vfoptions.pi_z_J=pi_z_J;
        vfoptions.z_grid_J=z_grid_J;
        simoptions.pi_z_J=pi_z_J;
        simoptions.z_grid_J=z_grid_J;
    end
    % If overlap=1 then z_grid_J and/or pi_z_J depends on General eqm
    % parameters, so it must be calculated inside the function.
end

%%

if N_p~=0
    [p_eqm_vec,p_eqm_index,GeneralEqmConditions]=HeteroAgentStationaryEqm_Case1_FHorz_pgrid(jequaloneDist,AgeWeightParamNames, n_d, n_a, n_z, N_j, n_p, pi_z, d_grid, a_grid, z_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Parameters, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames, heteroagentoptions, simoptions, vfoptions);
    return
end

%% Otherwise, use fminsearch to find the general equilibrium

GeneralEqmConditionsFn=@(GEprices) HeteroAgentStationaryEqm_Case1_FHorz_subfn(GEprices, jequaloneDist,AgeWeightParamNames, n_d, n_a, n_z, N_j, l_p, pi_z, d_grid, a_grid, z_grid, ReturnFn, FnsToEvaluate, GeneralEqmEqns, Parameters, DiscountFactorParamNames, ReturnFnParamNames, FnsToEvaluateParamNames, GeneralEqmEqnParamNames, GEPriceParamNames, heteroagentoptions, simoptions, vfoptions)

GEprices0=nan(length(GEPriceParamNames),1);
for ii=1:length(GEPriceParamNames)
    GEprices0(ii)=Parameters.(GEPriceParamNames{ii});
end

% fprintf('GEprices0 is: \n')
% GEprices0

minoptions = optimset('TolX',heteroagentoptions.toleranceGEprices,'TolFun',heteroagentoptions.toleranceGEcondns);
if heteroagentoptions.fminalgo==0 % fzero doesn't appear to be a good choice in practice, at least not with it's default settings.
    heteroagentoptions.multiGEcriterion=0;
    [p_eqm_vec,GeneralEqmConditions]=fzero(GeneralEqmConditionsFn,GEprices0,minoptions);    
elseif heteroagentoptions.fminalgo==1
    [p_eqm_vec,GeneralEqmConditions]=fminsearch(GeneralEqmConditionsFn,GEprices0,minoptions);
else
    [p_eqm_vec,GeneralEqmConditions]=fminsearch(GeneralEqmConditionsFn,GEprices0,minoptions);
end

p_eqm_index=nan; % If not using p_grid then this is irrelevant/useless

for ii=1:length(GEPriceParamNames)
    p_eqm.(GEPriceParamNames{ii})=p_eqm_vec(ii);
end

% if nargout>1
%     [p_eqm,p_eqm_index,GeneralEqmConditions]
% end
    
end