% ------------------------------------------------------------------- 
% Extended Square-root Kalman Filter 
%      Type: Covariance filtering
%    Method: Cholesky-based implementation with upper triangular factors
%      From: Two stages, a posteriori form
% Recursion: Riccati-type underlying recursion
%   Authors: Maria Kulikova: maria dot kulikova at ist dot utl dot pt 
% ------------------------------------------------------------------- 
% References:
%     Park P., Kailath T. (1995) New square-root algorithms for Kalman 
%     filtering, IEEE Trans. Automat. Contr. 40(5):895-899.
%     DOI: 10.1109/9.384225 
% ------------------------------------------------------------------- 
% Input:
%     matrices        - system matrices F,H,Q etc
%     initials_filter - initials x0,P0
%     measurements    - measurements (where y(t_k) is the k-th column)
% Output:
%     neg_LLF     - negative log LF
%     hatX        - filtered estimate (history) 
%     hatDP       - diag of the filtered error covariance (history)
% ------------------------------------------------------------------- 
function [neg_LLF,hatX,hatDP] = Riccati_KF_eSR(matrices,initials_filter,measurements)
   [F,G,Q,H,R] = deal(matrices{:});         % get system matrices
         [X,P] = deal(initials_filter{:});  % initials for the filter 
          
        [m,n]  = size(H);                % dimensions
       N_total = size(measurements,2);   % number of measurements
          hatX = zeros(n,N_total+1);     % prelocate for efficiency
         hatDP = zeros(n,N_total+1);     % prelocate for efficiency

        if isdiag(Q), Q_sqrt = diag(sqrt(diag(Q))); else  Q_sqrt = chol(Q,'upper'); end; clear Q; % Cholesky factorization Q = A'*A
        GQsqrt = G*Q_sqrt';                % compute once the new G*Q^{1/2}
        if isdiag(R), sqrtR = diag(sqrt(diag(R))); else  sqrtR = chol(R,'upper'); end; clear R; 
        if isdiag(P), sqrtP = diag(sqrt(diag(P))); else  sqrtP = chol(P,'upper'); end;  
            PX = (sqrtP')\X;               % initials for the filter 
        
  neg_LLF = 1/2*m*log(2*pi)*N_total; % initial value for the neg Log LF
hatX(:,1) = X; hatDP(:,1) = diag(P); % save initials at the first entry
for k = 1:N_total                 
   [PX,sqrtP]                  = esrcf_predict(PX,sqrtP,F,GQsqrt); 
   [PX,sqrtP,norm_ek,sqrt_Rek] = esrcf_update(PX,sqrtP,measurements(:,k),H,sqrtR);
   
   neg_LLF = neg_LLF+1/2*log(det(sqrt_Rek'*sqrt_Rek))+1/2*(norm_ek')*norm_ek;
   hatX(:,k+1) = sqrtP'*PX; hatDP(:,k+1) = diag(sqrtP'*sqrtP); % save estimates   
 end;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%   Time update: a priori estimates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [PX,sqrtP] = esrcf_predict(PX,sqrtP,F,G)
     [n,q]      = size(G);
     PreArray   = [sqrtP*F', PX; G', zeros(q,1);];
   % --- triangularize the first two (block) columns only ---          
   [Oth,PostArray] = qr(PreArray(:,1:n));  
    PostArrayRest  = Oth'*PreArray(:,n+1:end); 
   % -- read-off the resulted quantities -------------------
    sqrtP        = PostArray(1:n,1:n);    % Predicted factor of P        
    PX           = PostArrayRest(1:n,:);  % Predicted PX element        
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%   Measurement update: a posteriori estimates
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [PX,sqrtP,norm_residual,sqrtRe] = esrcf_update(PX,sqrtP,z,H,sqrtR)
    [m,n]     = size(H);
    PreArray  = [sqrtR,    zeros(m,n),  -sqrtR'\z; 
                 sqrtP*H', sqrtP,        PX;];
   % --- triangularize the first two (block) columns only ---          
   [Oth,PostArray] = qr(PreArray(:,1:m+n));  
    PostArrayRest  = Oth'*PreArray(:,m+n+1:end); 
   % -- read-off the resulted quantities -------------------
           sqrtRe  =  PostArray(1:m,1:m);         % Filtered factor of R_{e,k}             
     norm_residual = -PostArrayRest(1:m,:);       % normalized innovations 
                PX =  PostArrayRest(1+m:m+n,:);   % Filtered PX element
             sqrtP =  PostArray(m+1:m+n,m+1:m+n); % Filtered factor of P
end
