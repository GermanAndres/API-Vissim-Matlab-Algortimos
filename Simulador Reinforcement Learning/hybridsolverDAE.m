function [Hdae_obj t x j] = hybridsolverDAE(Hdae_obj,y0,TSPAN,JSPAN,rule);

% [t y j] = hybridsolverDAE( f,g,C,D,y0,TSPAN,JSPAN,rule,options,maxStepCoefficient)
% HYBRIDSOLVER solves hybrid equations
%   [t y j] = hybridsolver( f,g,C,D,y0,TSPAN,JSPAN) will integrate
%   y'=f(y) and jump by the rule y = g(y). y is a vector with the same
%   length as y0. Both must return a vector with the
%   equal length as y0.
%
%   inside = C(x) returns 0 if outside of C and 1 inside of C
%
%   inside = D(x) returns 0 if outside of D and 1 inside of D
%
%   TSPAN = [TSTART TFINAL] is the time interval. JSPAN = [JSTART JSTOP] is
%       the interval for discrete jumps. The algorithm stop when the first stop
%       condition is reached.
%
%   rule for jumps
%       rule = 1 -> priority for jumps
%       rule = 2 (default) -> priority for flows
%
%   options - options for the solver see odeset f.ex.
%       options = odeset('RelTol',1e-6);
%
%   maxStepCoefficient - set the maximum step length. At each run of the
%       integrator the option 'MaxStep' is set to (time length of last
%       integration)*maxStepCoefficient.
%       Default value = 0.1
%
global A B;

C = Hdae_obj.C;
D = Hdae_obj.D;
Csigma = Hdae_obj.Csigma;
E = Hdae_obj.E;
A = Hdae_obj.A;
B = Hdae_obj.B;
G = Hdae_obj.G;
Cea = Hdae_obj.Cea;
Pi = Hdae_obj.Pi;
epsilon = 1e-3;
if ~exist('options','var')
    options = odeset();
end

if ~exist('maxStepCoefficient','var')
    maxStepCoefficient = .2;
end
if isempty(B)
    B = zeros(n,1,length(Hdae_obj.isRegular));
end

% simulation horizon
tstart = TSPAN(1);
tfinal = TSPAN(end);

% simulate
options = odeset(options,'Events',@(t,x) zeroevents(x,C,D,Csigma,rule,Cea,epsilon));
tout = tstart;
yout(:,1) = y0;
jout = JSPAN(1);
j = jout(end);

% Jump if jump is prioritized:
if rule == 1
    while (j<JSPAN(end))
        % Check if value it is possible to jump current position
        insideD = D(yout(:,end))||Csigma(yout(:,end),Cea,epsilon);
        if insideD == 1
            [j tout yout jout] = jump(G,D,Cea,Pi,epsilon,j,tout,yout,jout);
        else
            break;
        end
    end
end
% fprintf('Completed: %3.0f%%',0);
while (j < JSPAN(end) && tout(end) < TSPAN(end))
    % Check if it is possible to flow from current position
    insideC = C(yout(:,end));
    if insideC == 1
        %         q = yout(end,nx+2);
        sigma = round(yout(end,end));
        M = E(:,:,sigma);
        options = odeset(options,'Mass',M,'Stats','off');
        [t,y] = ode23s(@(t,x) fHdae(x),[tout(end) tfinal],yout(:,end), options);
        nt = length(t);
        tout = [tout; t];
        yout = [yout, y'];
        jout = [jout; j*ones(1,nt)'];
        % A good guess of a valid first time step is the length of
        % the last valid time step, so use it for faster computation.
        options = odeset(options,'InitialStep',t(end)-t(nt-1),...
            'MaxStep',(t(end)-t(1))*maxStepCoefficient);
    end
    
    %Check if it possible to jump
    insideD = D(yout(:,end))||Csigma(yout(:,end),Cea,epsilon);
    if insideD == 0 % Not in C, not in D, not in Cea
        break;
    else
        if rule == 1
            while (j<JSPAN(end))
                % Check if value it is possible to jump current position
                insideD = D(yout(:,end))||Csigma(yout(:,end),Cea,epsilon);
                if insideD == 1
                    [j tout yout jout] = jump(G,D,Cea,Pi,epsilon,j,tout,yout,jout);
                else
                    break;
                end
            end
        else
            [j tout yout jout] = jump(G,D,Cea,Pi,epsilon,j,tout,yout,jout);
        end
    end
%     fprintf('\b\b\b\b%3.0f%%',100*tout(end)/TSPAN(end));
end
% fprintf('\b\b\b\b%3.0f%%',100*tout(end)/TSPAN(end));
t = tout;
x = yout;
j = jout;
Hdae_obj.state = yout(:,end);
Hdae_obj.sigma = yout(end,end);
% fprintf('\nDone\n');
end

function [value,isterminal,direction] = zeroevents(x,C,D,Csigma,rule,Cea,epsilon)
isterminal = 1;
direction = -1;
insideC = C(x);
insideCsigma = Csigma(x,Cea,epsilon);
if insideC == 0
    % Outside of C
    value = 0;
elseif (rule == 1)
    % If priority for jump stop if inside D
    insideD = D(x)||insideCsigma;
    if insideD == 1
        % Inside D, inside C
        value = 0;
    else
        % outside D, inside C
        value = 1;
    end
else
    % If inside C and not priority for jump or priority of jump and outside
    % of D
    value = 1;
end
end

function [j tout yout jout] = jump(g,D,Cea,Pi,epsilon,j,tout,yout,jout)
% Jump
x = yout(:,end);
sigma = round(x(end));
j = j+1;
outsideCsigma = Csigma(x,Cea,epsilon);
insideD = D(x);
if outsideCsigma
    y = Pi(:,:,sigma)*x;
elseif insideD
    y = Pi(:,:,sigma)*g(x);
end
% Save results
tout = [tout; tout(end)];
yout = [yout, y];
jout = [jout; j];
end
