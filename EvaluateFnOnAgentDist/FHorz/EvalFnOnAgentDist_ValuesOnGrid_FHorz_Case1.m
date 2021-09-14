function ValuesOnGrid=EvalFnOnAgentDist_ValuesOnGrid_FHorz_Case1(PolicyIndexes, FnsToEvaluate, Parameters, FnsToEvaluateParamNames, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, Parallel,simoptions)
% Parallel is an optional input.

if n_d(1)==0
    l_d=0;
else
    l_d=length(n_d);
end
l_a=length(n_a);
l_z=length(n_z);
N_a=prod(n_a);
N_z=prod(n_z);

if exist('Parallel','var')==0
    Parallel=1+(gpuDeviceCount>0); % GPU where available, otherwise parallel CPU.
end


eval('fieldexists_ExogShockFn=1;simoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')
eval('fieldexists_ExogShockFnParamNames=1;simoptions.ExogShockFnParamNames;','fieldexists_ExogShockFnParamNames=0;')

if Parallel==2
    ValuesOnGrid=zeros(N_a*N_z,N_j,length(FnsToEvaluate),'gpuArray');
        
    PolicyValues=PolicyInd2Val_FHorz_Case1(PolicyIndexes,n_d,n_a,n_z,N_j,d_grid,a_grid, Parallel);
    permuteindexes=[1+(1:1:(l_a+l_z)),1,1+l_a+l_z+1];
    PolicyValuesPermute=permute(PolicyValues,permuteindexes); %[n_a,n_z,l_d+l_a,N_j]
    
    PolicyValuesPermuteVec=reshape(PolicyValuesPermute,[N_a*N_z*(l_d+l_a),N_j]);
    for ii=1:length(FnsToEvaluate)
        Values=nan(N_a*N_z,N_j,'gpuArray');
        for jj=1:N_j
            if fieldexists_ExogShockFn==1
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
            end
            
            % Includes check for cases in which no parameters are actually required
            if isempty(FnsToEvaluateParamNames(ii).Names) % || strcmp(FnsToEvaluateParamNames(1),'')) % check for 'FnsToEvaluateParamNames={}'
                FnToEvaluateParamsVec=[];
            else
                FnToEvaluateParamsVec=gpuArray(CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(ii).Names,jj));
            end
            Values(:,jj)=reshape(EvalFnOnAgentDist_Grid_Case1(FnsToEvaluate{ii}, FnToEvaluateParamsVec,reshape(PolicyValuesPermuteVec(:,jj),[n_a,n_z,l_d+l_a]),n_d,n_a,n_z,a_grid,z_grid,Parallel),[N_a*N_z,1]);
        end
        ValuesOnGrid(:,:,ii)=Values;
    end
    
else
    ValuesOnGrid=zeros(N_a*N_z,N_j,length(FnsToEvaluate),'gpuArray');

    a_gridvals=CreateGridvals(n_a,a_grid,2);
    z_gridvals=CreateGridvals(n_z,z_grid,2);
    
    sizePolicyIndexes=size(PolicyIndexes);
    if sizePolicyIndexes(2:end)~=[N_a,N_z,N_j] % If not in vectorized form
        PolicyIndexes=reshape(PolicyIndexes,[sizePolicyIndexes(1),N_a,N_z,N_j]);
    end
    
    for ii=1:length(FnsToEvaluate)
        Values=zeros(N_a,N_z,N_j);
        if l_d==0
            for jj=1:N_j
                if fieldexists_ExogShockFn==1
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
                    z_gridvals=CreateGridvals(n_z,z_grid,2);
                end

                
                [~, aprime_gridvals]=CreateGridvals_Policy(PolicyIndexes(:,:,:,jj),n_d,n_a,n_a,n_z,d_grid,a_grid,1, 2);
                if ~isempty(FnsToEvaluateParamNames(ii).Names)
                    FnToEvaluateParamsCell=num2cell(CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(ii).Names,jj));
                end
                for a_c=1:N_a
                    for z_c=1:N_z
                        % Includes check for cases in which no parameters are actually required
                        if isempty(FnsToEvaluateParamNames(ii).Names)
                             Values(a_c,z_c,jj)=FnsToEvaluate{ii}(aprime_gridvals{a_c+(z_c-1)*N_a,:},a_gridvals{a_c,:},z_gridvals{z_c,:});
                        else
                             Values(a_c,z_c,jj)=FnsToEvaluate{ii}(aprime_gridvals{a_c+(z_c-1)*N_a,:},a_gridvals{a_c,:},z_gridvals{z_c,:},FnToEvaluateParamsCell{:});
                        end
                    end
                end
            end
        else
            for jj=1:N_j
                if fieldexists_ExogShockFn==1
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
                    z_gridvals=CreateGridvals(n_z,z_grid,2);
                end
                
                [d_gridvals, aprime_gridvals]=CreateGridvals_Policy(PolicyIndexes(:,:,:,jj),n_d,n_a,n_a,n_z,d_grid,a_grid,1, 2);
                if ~isempty(FnsToEvaluateParamNames(ii).Names)
                    FnToEvaluateParamsCell=num2cell(CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(ii).Names,jj));
                end
                for a_c=1:N_a
                    for z_c=1:N_z
                        % Includes check for cases in which no parameters are actually required
                        if isempty(FnsToEvaluateParamNames(ii).Names)
                             Values(a_c,z_c,jj)=FnsToEvaluate{ii}(d_gridvals{a_c+(z_c-1)*N_a,:},aprime_gridvals{a_c+(z_c-1)*N_a,:},a_gridvals{a_c,:},z_gridvals{z_c,:});
                        else
                             Values(a_c,z_c,jj)=FnsToEvaluate{ii}(d_gridvals{a_c+(z_c-1)*N_a,:},aprime_gridvals{a_c+(z_c-1)*N_a,:},a_gridvals{a_c,:},z_gridvals{z_c,:},FnToEvaluateParamsCell{:});
                        end
                    end
                end
            end
        end
        ValuesOnGrid(:,:,ii)=reshape(Values,[N_a*N_z,N_j,1]);
    end
    
end


% Change the ordering and size so that ProbDensityFns has same kind of
% shape as StationaryDist, except first dimension indexes the
% 'FnsToEvaluate'.
ValuesOnGrid=permute(ValuesOnGrid,[3,1,2]);
ValuesOnGrid=reshape(ValuesOnGrid,[length(FnsToEvaluate),n_a,n_z,N_j]);

end
