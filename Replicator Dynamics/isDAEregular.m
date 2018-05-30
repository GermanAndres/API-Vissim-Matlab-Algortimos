function [flagReg] = isDAEregular(E,A)
%% -------------------------------------------------------------------------
% isDAEregular.m
% -------------------------------------------------------------------------
% is the DAE system regular?
% By Pablo �a�ez
% Stephan Trenn 2009
% Universidad de los Andes
% Bogot�, Colombia
% July 2011
% -------------------------------------------------------------------------
%% -------------------------------------------------------------------------
% VARIABLE NAMES AND EXPLICATION
% -------------------------------------------------------------------------

%% -------------------------------------------------------------------------

syms s
polyn = det(s*E-A);
flagReg = (polyn~=0);