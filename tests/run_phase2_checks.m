function results=run_phase2_checks(options)
%RUN_PHASE2_CHECKS 21 项原回归 + 9 项会话测试 + 7 项界面测试。
% RunAudio=true 额外执行 2 项真实声卡测试，会播放声音；默认不播放。
arguments
    options.RunAudio (1,1) logical = false
end
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root,fullfile(root,'src'),fullfile(root,'gui'));
out=fullfile(root,'outputs','results','phase2'); if ~isfolder(out), mkdir(out); end
diary(fullfile(out,'tests.log')); cleanup=onCleanup(@()diary('off'));
fprintf('MATLAB: %s\nUTC: %s\nRunAudio: %d\n',version,string(datetime('now','TimeZone','UTC')),options.RunAudio);
suite=[testsuite(fullfile(root,'tests','testDtmf.m')), ...
    testsuite(fullfile(root,'tests','testDtmfSession.m')), ...
    testsuite(fullfile(root,'tests','testDtmfGui.m'))];
if options.RunAudio, suite=[suite,testsuite(fullfile(root,'tests','testDtmfAudio.m'))]; end
runner=matlab.unittest.TestRunner.withTextOutput;
runner.addPlugin(matlab.unittest.plugins.XMLPlugin.producingJUnitFormat(fullfile(out,'junit.xml')));
results=runner.run(suite);
save(fullfile(out,'test_results.mat'),'results');
summary=table(string({results.Name})',[results.Passed]',[results.Failed]',[results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','DurationSeconds'});
writetable(summary,fullfile(out,'test_results.csv'));
fprintf('TOTAL=%d PASSED=%d FAILED=%d INCOMPLETE=%d\n',numel(results),sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]));
assert(all([results.Passed]),'dtmf:Phase2ChecksFailed','有失败或未完成项目，详见 phase2 测试记录。');
end
