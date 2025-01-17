function SimPanelValues=SimPanelValues_FHorz_PType_Case1(InitialDist,Policy,ValuesFns,ValuesFnsParamNames,Parameters,n_d,n_a,n_z,N_j,N_i,d_grid,a_grid,z_grid,pi_z, simoptions)
% Simulates a panel based on PolicyIndexes of 'numbersims' agents of length
% 'simperiods' beginning from randomly drawn InitialDist.
%
% InitialDist can be inputed as over the finite time-horizon (j), or
% without a time-horizon in which case it is assumed to be an InitialDist
% for time/age j=1. (So InitialDist is either n_a-by-n_z-by-n_j-by-n_i, or n_a-by-n_z-by-n_i)

N_a=prod(n_a);
N_z=prod(n_z);
N_d=prod(n_d);

%% Check which simoptions have been declared, set all others to defaults 
if exist('simoptions','var')==1
    %Check simoptions for missing fields, if there are some fill them with the defaults
    if isfield(simoptions,'parallel')==0
        simoptions.parallel=2;
    end
    if isfield(simoptions,'verbose')==0
        simoptions.verbose=0;
    end
    if isfield(simoptions,'simperiods')==0
        simoptions.simperiods=N_j;
    end
    if isfield(simoptions,'numbersims')==0
        simoptions.numbersims=10^3;
    end
else
    %If simoptions is not given, just use all the defaults
    simoptions.parallel=2;
    simoptions.verbose=0;
    simoptions.simperiods=N_j;
    simoptions.numbersims=10^3;
end

if n_d(1)==0
    l_d=0;
else
    l_d=length(n_d);
end
l_a=length(n_a);
l_z=length(n_z);

if simoptions.parallel~=2
    d_grid=gather(d_grid);
    a_grid=gather(a_grid);
    z_grid=gather(z_grid);
end

%%
numelInitialDist=gather(numel(InitialDist)); % Use it multiple times so precalculate once here for speed
if N_a*N_z*N_i==numelInitialDist %Does not depend on N_j
    InitialDist=reshape(InitialDist,[N_a,N_z,N_i]);
    PType_mass=permute(sum(sum(InitialDist,1),2),[3,2,1]);
else % Depends on N_j
    InitialDist=reshape(InitialDist,[N_a,N_z,N_j,N_i]);
    PType_mass=permute(sum(sum(sum(InitialDist,1),2),3),[4,3,2,1]);
end
PType_numbersims=round(PType_mass*simoptions.numbersims);

SimPanelValues=nan(length(ValuesFns)+1,simoptions.simperiods,simoptions.numbersims); % +1 is the fixed type.
for ii=1:N_i
    simoptions_ii=simoptions;
    if simoptions_ii.verbose==1
        sprintf('Fixed type: %i of %i',ii, N_i)
    end
    simoptions_ii.numbersims=PType_numbersims(ii);
    if isfield(simoptions,'ExogShockFn') % If this exists, so will ExogShockFnParamNames, but I still treat them seperate as makes the code easier to read
        if length(simoptions.ExogShockFn)==1
            if simoptions_ii.ExogShockFn==1
            end
        else
            if simoptions.ExogShockFn(ii)==1
                simoptions_ii.ExogShockFn=simoptions.ExogShockFn(ii);
            end
        end
    end
    if isfield(simoptions,'ExogShockFnParamNames')
        if length(simoptions.ExogShockFnParamNames)==1
            if simoptions.ExogShockFnParamNames==1
            end
        else
            if simoptions.ExogShockFnParamNames(ii)==1
                simoptions_ii.ExogShockFnParamNames=simoptions.ExogShockFnParamNames(ii);
            end
        end
    end
    
    % Go through everything which might be dependent on fixed type (PType)
    % [THIS could be better coded, 'names' are same for all these and just need to be found once outside of ii loop]
    d_grid_temp=d_grid;
    if isa(d_grid,'struct')
        names=fieldnames(d_grid);
        d_grid_temp=d_grid.(names{ii});
    end
    a_grid_temp=a_grid;
    if isa(a_grid,'struct')
        names=fieldnames(a_grid);
        a_grid_temp=a_grid.(names{ii});
    end
    z_grid_temp=z_grid;
    if isa(z_grid,'struct')
        names=fieldnames(z_grid);
        z_grid_temp=z_grid.(names{ii});
    end
    pi_z_temp=pi_z;
    if isa(pi_z,'struct')
        names=fieldnames(pi_z);
        pi_z_temp=pi_z.(names{ii});
    end
    Policy_temp=Policy;
    if isa(Policy,'struct')
        names=fieldnames(Policy);
        Policy_temp=Policy.(names{ii});
    end
    if N_a*N_z*N_i==numelInitialDist %Does not depend on N_j
        InitialDist_temp=InitialDist(:,:,ii);
        InitialDist_temp=InitialDist_temp./(sum(sum(InitialDist_temp)));
    else % Depends on N_j
        InitialDist_temp=InitialDist(:,:,:,ii);
        InitialDist_temp=InitialDist_temp./(sum(sum(sum(InitialDist_temp))));
    end
    
    % Parameters are allowed to be given as structure, or as vector/matrix
    % (in terms of their dependence on fixed type). So go through each of
    % these in turn.
    Parameters_temp=Parameters;
    FullParamNames=fieldnames(Parameters);
    nFields=length(FullParamNames);
    for kField=1:nFields
        if isa(Parameters.(FullParamNames{kField}), 'struct') % Check for permanent type in structure form
            names=fieldnames(Parameters.(FullParamNames{kField}));
            Parameters_temp.(FullParamNames{kField})=Parameters.(FullParamNames{kField}).(names{ii});
        elseif sum(size(Parameters.(FullParamNames{kField}))==N_i)==1 % Check for permanent type in vector/matrix form.
            temp=Parameters.(FullParamNames{kField});
            [~,ptypedim]=max(size(Parameters.(FullParamNames{kField}))==N_i); % Parameters as vector/matrix can be at most two dimensional, figure out which relates to PType.
            if ptypedim==1
                Parameters_temp.(FullParamNames{kField})=temp(ii,:);
            elseif ptypedim==2
                Parameters_temp.(FullParamNames{kField})=temp(:,ii);
            end
        end
    end
    
    SimPanelValues_ii=SimPanelValues_FHorz_Case1(InitialDist_temp,Policy_temp,ValuesFns,ValuesFnsParamNames,Parameters_temp,n_d,n_a,n_z,N_j,d_grid_temp,a_grid_temp,z_grid_temp,pi_z_temp, simoptions_ii);
    
    if ii==1
        SimPanelValues(1:length(ValuesFns),:,1:sum(PType_numbersims(1:ii)))=SimPanelValues_ii;
        SimPanelValues(length(ValuesFns)+1,:,1:sum(PType_numbersims(1:ii)))=ii*ones(1,simoptions_ii.simperiods,PType_numbersims(ii));
    else
        SimPanelValues(1:length(ValuesFns),:,(1+sum(PType_numbersims(1:(ii-1)))):sum(PType_numbersims(1:ii)))=SimPanelValues_ii;
        SimPanelValues(length(ValuesFns)+1,:,(1+sum(PType_numbersims(1:(ii-1)))):sum(PType_numbersims(1:ii)))=ii*ones(1,simoptions_ii.simperiods,PType_numbersims(ii));
    end
    
end
%%




end



