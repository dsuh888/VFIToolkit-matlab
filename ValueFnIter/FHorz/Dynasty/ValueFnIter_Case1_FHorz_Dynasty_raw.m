function [V,Policy2]=ValueFnIter_Case1_FHorz_Dynasty_raw(n_d,n_a,n_z,N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)

N_d=prod(n_d);
N_a=prod(n_a);
N_z=prod(n_z);

V=zeros(N_a,N_z,N_j,'gpuArray');
Policy=zeros(N_a,N_z,N_j,'gpuArray'); %first dim indexes the optimal choice for d and aprime rest of dimensions a,z

%%

eval('fieldexists_pi_z_J=1;vfoptions.pi_z_J;','fieldexists_pi_z_J=0;')
eval('fieldexists_ExogShockFn=1;vfoptions.ExogShockFn;','fieldexists_ExogShockFn=0;')
eval('fieldexists_ExogShockFnParamNames=1;vfoptions.ExogShockFnParamNames;','fieldexists_ExogShockFnParamNames=0;')

if vfoptions.lowmemory>0
    special_n_z=ones(1,length(n_z));
    z_gridvals=CreateGridvals(n_z,z_grid,1);
end
if vfoptions.lowmemory>1
    special_n_a=ones(1,length(n_a));
    a_gridvals=CreateGridvals(n_a,a_grid,1);
end

Vold=zeros(N_a,N_z,N_j);
tempcounter=1;
currdist=Inf;
while currdist>vfoptions.tolerance
    
    %% Iterate backwards through j.
    for reverse_j=0:N_j-1
        jj=N_j-reverse_j;
        
        if vfoptions.verbose==1
            sprintf('Finite horizon: %i of %i',jj, N_j)
        end
        
        
        % Create a vector containing all the return function parameters (in order)
        ReturnFnParamsVec=CreateVectorFromParams(Parameters, ReturnFnParamNames,jj);
        DiscountFactorParamsVec=CreateVectorFromParams(Parameters, DiscountFactorParamNames,jj);
        DiscountFactorParamsVec=prod(DiscountFactorParamsVec);
        
        if fieldexists_pi_z_J==1
            z_grid=vfoptions.z_grid_J(:,jj);
            pi_z=vfoptions.pi_z_J(:,:,jj);
        elseif fieldexists_ExogShockFn==1
            if fieldexists_ExogShockFnParamNames==1
                ExogShockFnParamsVec=CreateVectorFromParams(Parameters, vfoptions.ExogShockFnParamNames,jj);
                ExogShockFnParamsCell=cell(length(ExogShockFnParamsVec),1);
                for ii=1:length(ExogShockFnParamsVec)
                    ExogShockFnParamsCell(ii,1)={ExogShockFnParamsVec(ii)};
                end
                [z_grid,pi_z]=vfoptions.ExogShockFn(ExogShockFnParamsCell{:});
                z_grid=gpuArray(z_grid); pi_z=gpuArray(pi_z);
            else
                [z_grid,pi_z]=vfoptions.ExogShockFn(jj);
                z_grid=gpuArray(z_grid); pi_z=gpuArray(pi_z);
            end
        end
        
        if reverse_j==0 % So j==N_j
            VKronNext_j=V(:,:,1);
        else
            VKronNext_j=V(:,:,jj+1);
        end
        
        if vfoptions.lowmemory==0
            
            %if vfoptions.returnmatrix==2 % GPU
            ReturnMatrix=CreateReturnFnMatrix_Case1_Disc_Par2(ReturnFn, n_d, n_a, n_z, d_grid, a_grid, z_grid, ReturnFnParamsVec);
            
            %         %Calc the condl expectation term (except beta), which depends on z but
            %         %not on control variables
            %         EV=VKronNext_j.*(ones(N_a,1,'gpuArray')*dimshift(pi_z,1)); %THIS LINE IS LIKELY INCORRECT
            %         EV(isnan(EV))=0; %multilications of -Inf with 0 gives NaN, this replaces them with zeros (as the zeros come from the transition probabilites)
            %         EV=sum(EV,2);
            %
            %         entireEV=kron(EV,ones(N_d,1,1));
            %         entireRHS=ReturnMatrix+DiscountFactorParamsVec*entireEV*ones(1,N_a,N_z);
            %
            %         %Calc the max and it's index
            %         [Vtemp,maxindex]=max(entireRHS,[],3);
            %         V(:,:,j)=Vtemp;
            %         PolicyIndexes(:,:,j)=maxindex;
            
            for z_c=1:N_z
                ReturnMatrix_z=ReturnMatrix(:,:,z_c);
                
                %Calc the condl expectation term (except beta), which depends on z but
                %not on control variables
                EV_z=VKronNext_j.*(ones(N_a,1,'gpuArray')*pi_z(z_c,:));
                EV_z(isnan(EV_z))=0; %multilications of -Inf with 0 gives NaN, this replaces them with zeros (as the zeros come from the transition probabilites)
                EV_z=sum(EV_z,2);
                
                entireEV_z=kron(EV_z,ones(N_d,1));
                entireRHS_z=ReturnMatrix_z+DiscountFactorParamsVec*entireEV_z*ones(1,N_a,1);
                
                %Calc the max and it's index
                [Vtemp,maxindex]=max(entireRHS_z,[],1);
                V(:,z_c,jj)=Vtemp;
                Policy(:,z_c,jj)=maxindex;
            end
            
        elseif vfoptions.lowmemory==1
            for z_c=1:N_z
                z_val=z_gridvals(z_c,:);
                ReturnMatrix_z=CreateReturnFnMatrix_Case1_Disc_Par2(ReturnFn, n_d, n_a, special_n_z, d_grid, a_grid, z_val, ReturnFnParamsVec);
                
                %Calc the condl expectation term (except beta), which depends on z but
                %not on control variables
                EV_z=VKronNext_j.*(ones(N_a,1,'gpuArray')*pi_z(z_c,:));
                EV_z(isnan(EV_z))=0; %multilications of -Inf with 0 gives NaN, this replaces them with zeros (as the zeros come from the transition probabilites)
                EV_z=sum(EV_z,2);
                
                entireEV_z=kron(EV_z,ones(N_d,1));
                entireRHS_z=ReturnMatrix_z+DiscountFactorParamsVec*entireEV_z*ones(1,N_a,1);
                
                %Calc the max and it's index
                [Vtemp,maxindex]=max(entireRHS_z,[],1);
                V(:,z_c,jj)=Vtemp;
                Policy(:,z_c,jj)=maxindex;
            end
            
        elseif vfoptions.lowmemory==2
            for z_c=1:N_z
                %Calc the condl expectation term (except beta), which depends on z but
                %not on control variables
                EV_z=VKronNext_j.*(ones(N_a,1,'gpuArray')*pi_z(z_c,:));
                EV_z(isnan(EV_z))=0; %multilications of -Inf with 0 gives NaN, this replaces them with zeros (as the zeros come from the transition probabilites)
                EV_z=sum(EV_z,2);
                
                entireEV_z=kron(EV_z,ones(N_d,1));
                
                z_val=z_gridvals(z_c,:);
                for a_c=1:N_a
                    a_val=a_gridvals(z_c,:);
                    ReturnMatrix_az=CreateReturnFnMatrix_Case1_Disc_Par2(ReturnFn, n_d, special_n_a, special_n_z, d_grid, a_val, z_val, ReturnFnParamsVec);
                    
                    entireRHS_az=ReturnMatrix_az+DiscountFactorParamsVec*entireEV_z;
                    %Calc the max and it's index
                    [Vtemp,maxindex]=max(entireRHS_az);
                    V(a_c,z_c,jj)=Vtemp;
                    Policy(a_c,z_c,jj)=maxindex;
                end
            end
            
        end
    end
    
    Vdist=reshape(V-Vold,[N_a*N_z*N_j,1]); Vdist(isnan(Vdist))=0;
    currdist=max(abs(Vdist)); %IS THIS reshape() & max() FASTER THAN max(max()) WOULD BE?
    Vold=V;
    
    tempcounter=tempcounter+1;
    if vfoptions.verbose==1 && rem(tempcounter,10)==0
        fprintf('Value Fn Iteration: After %d steps, current distance is %8.2f \n', tempcounter, currdist);
    end    
end

%%
Policy2=zeros(2,N_a,N_z,N_j,'gpuArray'); %NOTE: this is not actually in Kron form
Policy2(1,:,:,:)=shiftdim(rem(Policy-1,N_d)+1,-1);
Policy2(2,:,:,:)=shiftdim(ceil(Policy/N_d),-1);

end