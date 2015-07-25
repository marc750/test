function [ c ] = my_find(a, b)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here
    [tf,loc] = ismember(a,b);
    tf = find(tf);
    [~,idx] = unique(loc(tf), 'first');
    c = tf(idx);
end

