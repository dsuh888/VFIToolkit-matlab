function SimPanelValues=SimPanelValues_FHorz_Case2(InitialDist,Policy,FnsToEvaluate,FnsToEvaluateParamNames,Parameters,n_d,n_a,n_z,N_j,d_grid,a_grid,z_grid,pi_z, Phi_aprimeFn,Case2_Type,PhiaprimeParamNames, simoptions)
% Simulates a panel based on PolicyIndexes of 'numbersims' agents of length
% 'simperiods' beginning from randomly drawn InitialDist.
% SimPanelValues is a 3-dimensional matrix with first dimension being the
% number of 'variables' to be simulated, second dimension is FHorz, and
% third dimension is the number-of-simulations.
%
% InitialDist can be inputed as over the finite time-horizon (j), or
% without a time-horizon in which case it is assumed to be an InitialDist
% for time j=1. (So InitialDist is either n_a-by-n_z-by-n_j, or n_a-by-n_z)

%% Check which simoptions have been declared, set all others to defaults 
if exist('simoptions','var')==1
    %Check simoptions for missing fields, if there are some fill them with the defaults
    if ~isfield(simoptions,'parallel')
        simoptions.parallel=1;
    end
    if ~isfield(simoptions,'verbose')
        simoptions.verbose=0;
    end
    if ~isfield(simoptions,'simperiods')
        simoptions.simperiods=N_j;
    end
    if ~isfield(simoptions,'numbersims')
        simoptions.numbersims=10^3;
    end    
    if ~isfield(simoptions,'dynasty')
        simoptions.dynasty=0;
    end 
    if ~isfield(simoptions,'agedependentgrids')
        simoptions.agedependentgrids=0;
    end 
    if isfield(simoptions,'ExogShockFn') % If using ExogShockFn then figure out the parameter names
        simoptions.ExogShockFnParamNames=getAnonymousFnInputNames(simoptions.ExogShockFn);
    end
else
    %If simoptions is not given, just use all the defaults
    simoptions.parallel=1;
    simoptions.verbose=0;
    simoptions.simperiods=N_j;
    simoptions.numbersims=10^3;
    simoptions.dynasty=0;
end

if prod(simoptions.agedependentgrids)~=0
    % Note d_grid is actually d_gridfn
    % Note a_grid is actually a_gridfn
    % Note z_grid is actually z_gridfn
    % Note pi_z is actually AgeDependentGridParamNames
    if simoptions.dynasty==0
        SimPanelValues=SimPanelValues_FHorz_Case2_AgeDepGrids(InitialDist,Policy,FnsToEvaluate,FnsToEvaluateParamNames,Parameters,n_d,n_a,n_z,N_j,d_grid,a_grid,z_grid,pi_z, Phi_aprimeFn,Case2_Type,PhiaprimeParamNames, simoptions);
    else % if simoptions.dynasty==1
        SimPanelValues=SimPanelValues_FHorz_Case2_AgeDepGrids_Dynasty(InitialDist,Policy,FnsToEvaluate,FnsToEvaluateParamNames,Parameters,n_d,n_a,n_z,N_j,d_grid,a_grid,z_grid,pi_z, Phi_aprimeFn,Case2_Type,PhiaprimeParamNames, simoptions);        
    end
    return
end

% N_d=prod(n_d);
N_a=prod(n_a);
N_z=prod(n_z);

l_d=length(n_d);
l_a=length(n_a);
l_z=length(n_z);

% if simoptions.parallel~=2 % Keep the grid on the gpu for the SimPanelIndexes_FHorz_Case2
%     d_grid=gather(d_grid);
%     a_grid=gather(a_grid);
%     z_grid=gather(z_grid);
% end

% NOTE: ESSENTIALLY ALL THE RUN TIME IS IN THIS COMMAND. WOULD BE GOOD TO OPTIMIZE/IMPROVE.
PolicyIndexesKron=KronPolicyIndexes_FHorz_Case2(Policy, n_d, n_a, n_z, N_j);%,simoptions); % Create it here as want it both here and inside SimPanelIndexes_FHorz_Case2 (which will recognise that it is already in this form)

if simoptions.dynasty==0
    SimPanelIndexes=SimPanelIndexes_FHorz_Case2(InitialDist,PolicyIndexesKron,n_d,n_a,n_z,N_j,d_grid, a_grid, z_grid, pi_z,Phi_aprimeFn,Case2_Type,Parameters,PhiaprimeParamNames, simoptions);
else % if simoptions.dynasty==1
    fprintf('ERROR: SimPanelValues with Dynasty is currently only implemented for age dependent grids (simoptions.agedependentgrids) \n')
    fprintf('ERROR: If you get this error and would have a use for these codes email me robertdkirkby@gmail.com and I will look at implementing them. \n')
end
% Move everything to cpu for what remains.
d_grid=gather(d_grid);
a_grid=gather(a_grid);
z_grid=gather(z_grid);
PolicyIndexesKron=gather(PolicyIndexesKron);

SimPanelValues=zeros(length(FnsToEvaluate), simoptions.simperiods, simoptions.numbersims);

%% Precompute the gridvals vectors.
a_gridvals=CreateGridvals(n_a,a_grid,1); % 1 at end indicates output as matrices.
dPolicy_gridvals=struct();
for jj=1:N_j
    % Make a three digit number out of jj
    if jj<10
        jstr=['j00',num2str(jj)];
    elseif jj>=10 && jj<100
        jstr=['j0',num2str(jj)];
    else
        jstr=['j',num2str(jj)];
    end
    [dPolicy_gridvals_j,~]=CreateGridvals_Policy(PolicyIndexesKron(:,:,jj),n_d,[],n_a,n_z,d_grid,[],2,1);
    dPolicy_gridvals.(jstr(:))=dPolicy_gridvals_j;
end

eval('fieldexists_ExogShockFn=1;simoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')
eval('fieldexists_ExogShockFnParamNames=1;simoptions.ExogShockFnParamNames;','fieldexists_ExogShockFnParamNames=0;')
eval('fieldexists_pi_z_J=1;simoptions.pi_z_J;','fieldexists_pi_z_J=0;')

if fieldexists_pi_z_J
    for jj=1:N_j
        fullgridvals(jj).z_gridvals=CreateGridvals(n_z,simoptions.z_grid_J(:,:,jj),1);
    end
elseif fieldexists_ExogShockFn==1
    for jj=1:N_j
        if fieldexists_ExogShockFnParamNames==1
            ExogShockFnParamsVec=CreateVectorFromParams(Parameters, simoptions.ExogShockFnParamNames,jj);
            ExogShockFnParamsCell=cell(length(ExogShockFnParamsVec),1);
            for kk=1:length(ExogShockFnParamsVec)
                ExogShockFnParamsCell(kk,1)={ExogShockFnParamsVec(kk)};
            end
            [z_grid,~]=simoptions.ExogShockFn(ExogShockFnParamsCell{:});
        else
            [z_grid,~]=simoptions.ExogShockFn(jj);
        end
        fullgridvals(jj).z_gridvals=CreateGridvals(n_z,z_grid,1);
    end
else
    z_gridvals=CreateGridvals(n_z,z_grid,1); % 1 at end indicates output as matrices.
    for jj=1:N_j
        fullgridvals(jj).z_gridvals=z_gridvals;
    end
end

%%
%% For sure the following could be made faster by parallelizing some stuff.
% Intelligent would be to sort everything by j value, then do all this,
% then unsort. (as dPolicy_gridvals depends on j value)
parfor ii=1:simoptions.numbersims
    SimPanelValues_ii=nan(length(FnsToEvaluate),simoptions.simperiods); % Want nan for unobserved (when finite time-horizon is reached, so after than agent is 'dead')
    SimPanel_ii=SimPanelIndexes(:,:,ii);
    for t=1:simoptions.simperiods
        j_ind=SimPanel_ii(end,t);
        if ~isnan(j_ind) % If the agent is still alive (j_ind=nan once agent dies)
            
            a_sub=SimPanel_ii(1:l_a,t);
            a_ind=sub2ind_homemade(n_a,a_sub);
            a_val=a_gridvals(a_ind,:);
            
            z_sub=SimPanel_ii((l_a+1):(l_a+l_z),t);
            z_ind=sub2ind_homemade(n_z,z_sub);
            z_val=fullgridvals(j_ind).z_gridvals(z_ind,:);
            
            % Make a three digit number out of j_ind
            if j_ind<10
                jstr=['j00',num2str(j_ind)];
            elseif j_ind>=10 && j_ind<100
                jstr=['j0',num2str(j_ind)];
            else
                jstr=['j',num2str(j_ind)];
            end
            
            az_ind=sub2ind_homemade([N_a,N_z],[a_ind,z_ind]);
            dPolicy_gridvals_j=dPolicy_gridvals.(jstr(:));
            d_val=dPolicy_gridvals_j(az_ind,:);

            for vv=1:length(FnsToEvaluate)
                if isempty(FnsToEvaluateParamNames(vv).Names)  % check for 'SSvalueParamNames={}'
                    tempcell=num2cell([d_val,a_val,z_val]');
                else
                    ValuesFnParamsVec=CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(vv).Names,j_ind);
                    tempcell=num2cell([d_val,a_val,z_val,ValuesFnParamsVec]');
                end
                SimPanelValues_ii(vv,t)=FnsToEvaluate{vv}(tempcell{:});
            end
        end
    end
    SimPanelValues(:,:,ii)=SimPanelValues_ii;
end


end



