function LorenzCurve=EvalFnOnAgentDist_LorenzCurve_FHorz_Case2(StationaryDist,PolicyIndexes, FnsToEvaluate, Parameters, FnsToEvaluateParamNames,n_d,n_a,n_z,N_j,d_grid,a_grid,z_grid,Parallel,npoints,simoptions)
% Returns a Lorenz Curve 100-by-1 that contains all of the quantiles from 1
% to 100. Unless the optional npoints input is used in which case it will be
% npoints-by-1.
% 
% Note that to unnormalize the Lorenz Curve you can just multiply it be the
% AggVars for the same variable. This will give you the inverse cdf.

if isa(StationaryDist,'struct')
    % Using Age Dependent Grids so send there
    fprintf('ERROR: EvalFnOnAgentDist_LorenzCurve_FHorz_Case2() does no yet allow for Age Dependent Grids \n')
    fprintf('IF YOU HAVE A need/use for this functionality, please contact me: robertdkirkby@gmail.com and I will implement it \n')
    dbstack
    return
end

if exist('npoints','var')==0
    npoints=100;
end

if n_d(1)==0
    l_d=0;
else
    l_d=length(n_d);
end
l_a=length(n_a);
l_z=length(n_z);
N_a=prod(n_a);
N_z=prod(n_z);

%% This implementation is slightly inefficient when shocks are not age dependent, but speed loss is fairly trivial
if exist('simoptions','var')
    if isfield(simoptions,'ExogShockFn') % If using ExogShockFn then figure out the parameter names
        simoptions.ExogShockFnParamNames=getAnonymousFnInputNames(simoptions.ExogShockFn);
    end
end
eval('fieldexists_ExogShockFn=1;simoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')
eval('fieldexists_ExogShockFnParamNames=1;simoptions.ExogShockFnParamNames;','fieldexists_ExogShockFnParamNames=0;')
eval('fieldexists_pi_z_J=1;simoptions.pi_z_J;','fieldexists_pi_z_J=0;')

if fieldexists_pi_z_J==1
    z_grid_J=simoptions.z_grid_J;
elseif fieldexists_ExogShockFn==1
    z_grid_J=zeros(sum(n_z),N_j);
    for jj=1:N_j
        if fieldexists_ExogShockFnParamNames==1
            ExogShockFnParamsVec=CreateVectorFromParams(Parameters, simoptions.ExogShockFnParamNames,jj);
            ExogShockFnParamsCell=cell(length(ExogShockFnParamsVec),1);
            for ii=1:length(ExogShockFnParamsVec)
                ExogShockFnParamsCell(ii,1)={ExogShockFnParamsVec(ii)};
            end
            [z_grid,~]=simoptions.ExogShockFn(ExogShockFnParamsCell{:});
        else
            [z_grid,~]=simoptions.ExogShockFn(jj);
        end
        z_grid_J(:,jj)=z_grid;
    end
else
    z_grid_J=repmat(z_grid,1,N_j);
end
if Parallel==2
    z_grid_J=gpuArray(z_grid_J);
end

if isfield(simoptions,'n_e')
    % Because of how FnsToEvaluate works I can just get the e variables and then 'combine' them with z
    eval('fieldexists_EiidShockFn=1;simoptions.EiidShockFn;','fieldexists_EiidShockFn=0;')
    eval('fieldexists_EiidShockFnParamNames=1;simoptions.EiidShockFnParamNames;','fieldexists_EiidShockFnParamNames=0;')
    eval('fieldexists_pi_e_J=1;simoptions.pi_e_J;','fieldexists_pi_e_J=0;')
    
    N_e=prod(simoptions.n_e);
    l_e=length(simoptions.n_e);
    
    if fieldexists_pi_e_J==1
        e_grid_J=simoptions.e_grid_J;
    elseif fieldexists_EiidShockFn==1
        e_grid_J=zeros(sum(simoptions.n_e),N_j);
        for jj=1:N_j
            if fieldexists_EiidShockFnParamNames==1
                EiidShockFnParamsVec=CreateVectorFromParams(Parameters, simoptions.EiidShockFnParamNames,jj);
                EiidShockFnParamsCell=cell(length(EiidShockFnParamsVec),1);
                for ii=1:length(EiidShockFnParamsVec)
                    EiidShockFnParamsCell(ii,1)={EiidShockFnParamsVec(ii)};
                end
                [e_grid,~]=simoptions.EiidShockFn(EiidShockFnParamsCell{:});
            else
                [e_grid,~]=simoptions.EiidShockFn(jj);
            end
            e_grid_J(:,jj)=gather(e_grid);
        end
    else
        e_grid_J=repmat(simoptions.e_grid,1,N_j);
    end
    
    % Now combine into z
    if n_z(1)==0
        l_z=l_e;
        n_z=simoptions.n_e;
        z_grid_J=e_grid_J;
    else
        l_z=l_z+l_e;
        n_z=[n_z,simoptions.n_e];
        z_grid_J=[z_grid_J; e_grid_J];
    end
    N_z=prod(n_z);
        
end

%% Implement new way of handling FnsToEvaluate
if isstruct(FnsToEvaluate)
    FnsToEvaluateStruct=1;
    clear FnsToEvaluateParamNames
    AggVarNames=fieldnames(FnsToEvaluate);
    for ff=1:length(AggVarNames)
        temp=getAnonymousFnInputNames(FnsToEvaluate.(AggVarNames{ff}));
        if length(temp)>(l_d+l_a+l_a+l_z)
            FnsToEvaluateParamNames(ff).Names={temp{l_d+l_a+l_a+l_z+1:end}}; % the first inputs will always be (d,aprime,a,z)
        else
            FnsToEvaluateParamNames(ff).Names={};
        end
        FnsToEvaluate2{ff}=FnsToEvaluate.(AggVarNames{ff});
    end    
    FnsToEvaluate=FnsToEvaluate2;
else
    FnsToEvaluateStruct=0;
end

%%
if Parallel==2
%     AggVars=zeros(length(FnsToEvaluateFn),1,'gpuArray');
    LorenzCurve=zeros(npoints,length(FnsToEvaluate),'gpuArray');
    StationaryDistVec=reshape(StationaryDist,[N_a*N_z*N_j,1]);
        
    PolicyValues=PolicyInd2Val_FHorz_Case2(PolicyIndexes,n_d,n_a,n_z,N_j,d_grid,2);
    permuteindexes=[1+(1:1:(l_a+l_z)),1,1+l_a+l_z+1];    
    PolicyValuesPermute=permute(PolicyValues,permuteindexes); %[n_a,n_z,l_d,N_d]

    PolicyValuesPermuteVec=reshape(PolicyValuesPermute,[N_a*N_z*l_d,N_j]);
    for i=1:length(FnsToEvaluate)
        Values=nan(N_a*N_z,N_j,'gpuArray');
        for jj=1:N_j
            z_grid=z_grid_J(:,jj);
            
            % Includes check for cases in which no parameters are actually required
            if isempty(FnsToEvaluateParamNames) %|| strcmp(SSvalueParamNames(i).Names(1),'')) % check for 'SSvalueParamNames={} or SSvalueParamNames={''}'
                FnToEvaluateParamsVec=[];
            else
                FnToEvaluateParamsVec=CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(i).Names,jj);
            end
            Values(:,jj)=reshape(EvalFnOnAgentDist_Grid_Case2(FnsToEvaluate{i}, FnToEvaluateParamsVec,reshape(PolicyValuesPermuteVec(:,jj),[n_a,n_z,l_d]),n_d,n_a,n_z,a_grid,z_grid,2),[N_a*N_z,1]);
        end

        Values=reshape(Values,[N_a*N_z*N_j,1]);
        
        WeightedValues=Values.*StationaryDistVec;
        WeightedValues(isnan(WeightedValues))=0; % Values of -Inf times weight of zero give nan, we want them to be zeros.
        %     AggVars(i)=sum(WeightedValues);
        
        [~,SortedValues_index] = sort(Values);
        
        SortedStationaryDistVec=StationaryDistVec(SortedValues_index);
        SortedWeightedValues=WeightedValues(SortedValues_index);
        
        CumSumSortedStationaryDistVec=cumsum(SortedStationaryDistVec);
        
%         %We now want to use interpolation, but this won't work unless all
%         %values in are CumSumSortedSteadyStateDist distinct. So we now remove
%         %any duplicates (ie. points of zero probability mass/density). We then
%         %have to remove the corresponding points of SortedValues. Since we
%         %are just looking for 100 points to make up our cdf I round all
%         %variables to 5 decimal points before checking for uniqueness (Do
%         %this because otherwise rounding in the ~12th decimal place was causing
%         % problems with vector not being sorted as strictly increasing.
%         [~,UniqueIndex] = unique(floor(CumSumSortedStationaryDistVec*10^5),'first');
%         CumSumSortedStationaryDistVec_NoDuplicates=CumSumSortedStationaryDistVec(sort(UniqueIndex));
%         SortedWeightedValues_NoDuplicates=SortedWeightedValues(sort(UniqueIndex));
%         
%         CumSumSortedWeightedValues_NoDuplicates=cumsum(SortedWeightedValues_NoDuplicates);
%         
%         %         % I now also get rid of all of those points after the cdf reaches
%         %         % 1-10^(-9). This is just because otherwise rounding in the ~12th
%         %         % decimal place was causing problems with vector not being
%         %         % 'sorted'.
%         %         firstIndex = find((CumSumSortedSteadyStateDistVec_NoDuplicates-1+10^(-9))>0,1,'first');
%         %         CumSumSortedSteadyStateDistVec_NoDuplicates=CumSumSortedSteadyStateDistVec_NoDuplicates(1:firstIndex);
%         %         CumSumSortedWeightedValues_NoDuplicates=CumSumSortedWeightedValues_NoDuplicates(1:firstIndex);
%         
%         InverseCDF_xgrid=gpuArray(1/npoints:1/npoints:1);
%         
%         
%         InverseCDF_SSvalues=interp1(CumSumSortedStationaryDistVec_NoDuplicates,CumSumSortedWeightedValues_NoDuplicates, InverseCDF_xgrid);
%         % interp1 cannot work for the point of InverseCDF_xgrid=1 (gives NaN). Since we
%         % have already sorted and removed duplicates this will just be the last
%         % point so we can just grab it directly.
%         %         InverseCDF_SSvalues(100)=CumSumSortedWeightedValues_NoDuplicates(end);
%         InverseCDF_SSvalues(npoints)=CumSumSortedWeightedValues_NoDuplicates(end);
%         % interp1 may have similar problems at the bottom of the cdf
%         j=1; %use j to figure how many points with this problem
%         while InverseCDF_xgrid(j)<CumSumSortedStationaryDistVec_NoDuplicates(1)
%             j=j+1;
%         end
%         for jj=1:j-1 %divide evenly through these states (they are all identical)
%             InverseCDF_SSvalues(jj)=(jj/j)*InverseCDF_SSvalues(j);
%         end
%         
%         SSvalues_LorenzCurve(i,:)=InverseCDF_SSvalues./SSvalues_AggVars(i);
        LorenzCurve(:,i)=LorenzCurve_subfunction_PreSorted(SortedWeightedValues,CumSumSortedStationaryDistVec,npoints,Parallel); 
    end
else
    LorenzCurve=zeros(npoints,length(FnsToEvaluate));
    
    a_gridvals=CreateGridvals(n_a,a_grid,1);
    StationaryDistVec=reshape(StationaryDist,[N_a*N_z*N_j,1]);
    
    sizePolicyIndexes=size(PolicyIndexes);
    if sizePolicyIndexes(2:end)~=[N_a,N_z,N_j] % If not in vectorized form
        PolicyIndexes=reshape(PolicyIndexes,[sizePolicyIndexes(1),N_a,N_z,N_j]);
    end
    dPolicy_gridvals=zeros(N_a*N_z,N_j);
    for jj=1:N_j
        dPolicy_gridvals(:,jj)=CreateGridvals_Policy(PolicyIndexes(:,:,jj),n_d,[],n_a,n_z,d_grid,[],2,1);
    end
    
    for i=1:length(FnsToEvaluate)
        Values=zeros(N_a,N_z,N_j);
        for jj=1:N_j 
            z_grid=z_grid_J(:,jj);
            z_gridvals=CreateGridvals(n_z,z_grid,1);
            
            for a_c=1:N_a
                a_val=a_gridvals(a_c,:);
                for z_c=1:N_z
                    z_val=z_gridvals(z_c,:);
                    az_c=sub2ind_homemade([N_a,N_z],[a_c,z_c]);
                    d_val=dPolicy_gridvals(az_c,jj);
                    % Includes check for cases in which no parameters are actually required
                    if isempty(FnsToEvaluateParamNames(i).Names)
                        tempv=[d_val,a_val,z_val];
                        tempcell=cell(1,length(tempv));
                        for temp_c=1:length(tempv)
                            tempcell{temp_c}=tempv(temp_c);
                        end
                    else
                        FnToEvaluateParamsVec=CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(i).Names,jj);
                        tempv=[d_val,a_val,z_val,FnToEvaluateParamsVec];
                        tempcell=cell(1,length(tempv));
                        for temp_c=1:length(tempv)
                            tempcell{temp_c}=tempv(temp_c);
                        end
                    end
                    Values(a_c,z_c,jj)=FnsToEvaluate{i}(tempcell{:});
                end
            end
        end

        Values=reshape(Values,[N_a*N_z*N_j,1]);
        
        WeightedValues=Values.*StationaryDistVec;
%         AggVars(i)=sum(WeightedValues);
        
        
        [~,SortedValues_index] = sort(Values);
        
        SortedStationaryDistVec=StationaryDistVec(SortedValues_index);
        SortedWeightedValues=WeightedValues(SortedValues_index);
        
        CumSumSortedStationaryDistVec=cumsum(SortedStationaryDistVec);
        
%         %We now want to use interpolation, but this won't work unless all
%         %values in are CumSumSortedSteadyStateDist distinct. So we now remove
%         %any duplicates (ie. points of zero probability mass/density). We then
%         %have to remove the corresponding points of SortedValues. 
%         [~,UniqueIndex] = uniquetol(CumSumSortedStationaryDistVec); % uses a default tolerance of 1e-6 for single-precision inputs and 1e-12 for double-precision inputs
% 
%         CumSumSortedStationaryDistVec_NoDuplicates=CumSumSortedStationaryDistVec(sort(UniqueIndex));
%         SortedWeightedValues_NoDuplicates=SortedWeightedValues(sort(UniqueIndex));
%         
%         CumSumSortedWeightedValues_NoDuplicates=cumsum(SortedWeightedValues_NoDuplicates);
%         
%         
%         InverseCDF_xgrid=1/npoints:1/npoints:1;
%         
%         InverseCDF_SSvalues=interp1(CumSumSortedStationaryDistVec_NoDuplicates,CumSumSortedWeightedValues_NoDuplicates, InverseCDF_xgrid);
%         % interp1 cannot work for the point of InverseCDF_xgrid=1 (gives NaN). Since we
%         % have already sorted and removed duplicates this will just be the last
%         % point so we can just grab it directly.
%         %         InverseCDF_SSvalues(100)=CumSumSortedWeightedValues_NoDuplicates(end);
%         InverseCDF_SSvalues(npoints)=CumSumSortedWeightedValues_NoDuplicates(end);
%         % interp1 may have similar problems at the bottom of the cdf
%         j=1; %use j to figure how many points with this problem
%         while InverseCDF_xgrid(j)<CumSumSortedStationaryDistVec_NoDuplicates(1)
%             j=j+1;
%         end
%         for jj=1:j-1 %divide evenly through these states (they are all identical)
%             InverseCDF_SSvalues(jj)=(jj/j)*InverseCDF_SSvalues(j);
%         end
%         
%         SSvalues_LorenzCurve(i,:)=InverseCDF_SSvalues./SSvalues_AggVars(i);
        LorenzCurve(:,i)=LorenzCurve_subfunction_PreSorted(SortedWeightedValues,CumSumSortedStationaryDistVec,npoints,Parallel);
    end
    
end


end