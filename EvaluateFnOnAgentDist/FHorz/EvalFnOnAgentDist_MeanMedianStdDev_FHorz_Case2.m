function MeanMedianStdDev=EvalFnOnAgentDist_MeanMedianStdDev_FHorz_Case2(StationaryDist, PolicyIndexes, FnsToEvaluate, Parameters,FnsToEvaluateParamNames, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, simoptions, AgeDependentGridParamNames) %pi_z,p_val
% Evaluates the aggregate value (weighted sum/integral) for each element of FnsToEvaluate
% options and AgeDependentGridParamNames is only needed when you are using Age Dependent Grids, otherwise this is not a required input.

if isa(StationaryDist,'struct')
    % Using Age Dependent Grids so send there
    % Note that in this case: d_grid is d_gridfn, a_grid is a_gridfn,
    % z_grid is z_gridfn. Parallel is options. AgeDependentGridParamNames is also needed. 
    MeanMedianStdDev=EvalFnOnAgentDist_MeanMedianStdDev_FHorz_Case2_AgeDepGrids(StationaryDist, PolicyIndexes, FnsToEvaluate, Parameters,FnsToEvaluateParamNames, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, simoptions, AgeDependentGridParamNames);
    return
end

l_d=length(n_d);
l_a=length(n_a);
l_z=length(n_z);
N_a=prod(n_a);
N_z=prod(n_z);

eval('fieldexists_ExogShockFn=1;simoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')
eval('fieldexists_ExogShockFnParamNames=1;simoptions.ExogShockFnParamNames;','fieldexists_ExogShockFnParamNames=0;')

if isa(StationaryDist,'gpuArray')% Parallel==2
%     SSvalues_AggVars=zeros(length(SSvaluesFn),1,'gpuArray');
    MeanMedianStdDev=zeros(length(FnsToEvaluate),3,'gpuArray');
    
    StationaryDistVec=reshape(StationaryDist,[N_a*N_z*N_j,1]);
    
    PolicyValues=PolicyInd2Val_FHorz_Case2(PolicyIndexes,n_d,n_a,n_z,N_j,d_grid,2);
    permuteindexes=[1+(1:1:(l_a+l_z)),1,1+l_a+l_z+1];    
    PolicyValuesPermute=permute(PolicyValues,permuteindexes); %[n_a,n_s,l_d+l_a]

    for i=1:length(FnsToEvaluate)
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
            if isempty(FnsToEvaluateParamNames) %|| strcmp(SSvalueParamNames(i).Names(1),'')) % check for 'SSvalueParamNames={} or SSvalueParamNames={''}'
                FnToEvaluateParamsVec=[];
            else
                FnToEvaluateParamsVec=CreateVectorFromParams(Parameters,FnsToEvaluateParamNames(i).Names,jj);
            end
            Values(:,jj)=reshape(ValuesOnSSGrid_Case2(FnsToEvaluate{i}, FnToEvaluateParamsVec,PolicyValuesPermute,n_d,n_a,n_z,a_grid,z_grid,2),[N_a*N_z,1]);
        end
        Values=reshape(Values,[N_a*N_z*N_j,1]);
%         StationaryDistVec=reshape(StationaryDistVec,[N_a*N_z*N_j,1]);
        % Mean
        MeanMedianStdDev(i,1)=sum(Values.*StationaryDistVec);
        % Median
        [SortedValues,SortedValues_index] = sort(Values);
        SortedStationaryDistVec=StationaryDistVec(SortedValues_index);
        median_index=find(cumsum(SortedStationaryDistVec)>=0.5,1,'first');
        MeanMedianStdDev(i,2)=SortedValues(median_index);
        % SSvalues_MeanMedianStdDev(i,2)=min(SortedValues(cumsum(SortedStationaryDistVec)>0.5));
        % Standard Deviation
        MeanMedianStdDev(i,3)=sqrt(sum(StationaryDistVec.*((Values-MeanMedianStdDev(i,1).*ones(N_a*N_z*N_j,1)).^2)));
    end
    
else
    MeanMedianStdDev=zeros(length(FnsToEvaluate),3);

    d_val=zeros(l_d,1);
    a_val=zeros(l_a,1);
    z_val=zeros(l_z,1);

    StationaryDistVec=reshape(StationaryDist,[N_a*N_z*N_j,1]);
    
    for i=1:length(FnsToEvaluate)
        Values=zeros(N_a,N_z,N_j);
        for j1=1:N_a
            a_ind=ind2sub_homemade_gpu([n_a],j1);
            for jj1=1:l_a
                if jj1==1
                    a_val(jj1)=a_grid(a_ind(jj1));
                else
                    a_val(jj1)=a_grid(a_ind(jj1)+sum(n_a(1:jj1-1)));
                end
            end
            
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
                
                for j2=1:N_z
                    z_ind=ind2sub_homemade_gpu([n_z],j2);
                    for jj2=1:l_z
                        if jj2==1
                            z_val(jj2)=z_grid(z_ind(jj2));
                        else
                            z_val(jj2)=z_grid(z_ind(jj2)+sum(n_z(1:jj2-1)));
                        end
                    end
                    d_ind=PolicyIndexes(1:l_d,j1,j2);
                    for kk1=1:l_d
                        if kk1==1
                            d_val(kk1)=d_grid(d_ind(kk1));
                        else
                            d_val(kk1)=d_grid(d_ind(kk1)+sum(n_d(1:kk1-1)));
                        end
                    end
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
                    Values(j1,j2,jj)=FnsToEvaluate{i}(tempcell{:});
                end
            end
        end
        Values=reshape(Values,[N_a*N_z*N_j,1]);
        
        % Mean
        MeanMedianStdDev(i,1)=sum(Values.*StationaryDistVec);
        % Median
        [SortedValues,SortedValues_index] = sort(Values);
        SortedStationaryDistVec=StationaryDistVec(SortedValues_index);
        median_index=find(cumsum(SortedStationaryDistVec)>=0.5,1,'first');
        MeanMedianStdDev(i,2)=SortedValues(median_index);
        % SSvalues_MeanMedianStdDev(i,2)=min(SortedValues(cumsum(SortedStationaryDistVec)>0.5));
        % Standard Deviation
        MeanMedianStdDev(i,3)=sqrt(sum(StationaryDistVec.*((Values-MeanMedianStdDev(i,1).*ones(N_a*N_z*N_j,1)).^2)));

    end

end


end

