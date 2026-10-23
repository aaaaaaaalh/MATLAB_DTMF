function results = run_tests
%RUN_TESTS 保存日志、MAT 文件、逐测试 CSV、JUnit XML；失败时 batch 返回非零状态。
root=fileparts(fileparts(mfilename('fullpath'))); addpath(fullfile(root,'src'));
out=fullfile(root,'outputs','results'); if ~isfolder(out), mkdir(out); end
diary(fullfile(out,'tests.log')); cleanup=onCleanup(@()diary('off')); %#ok<NASGU>
fprintf('MATLAB: %s\nUTC: %s\n',version,string(datetime('now','TimeZone','UTC')));
disp(ver('signal'));
import matlab.unittest.TestRunner
import matlab.unittest.plugins.XMLPlugin
suite=testsuite(fullfile(root,'tests','testDtmf.m'));
runner=TestRunner.withTextOutput;
runner.addPlugin(XMLPlugin.producingJUnitFormat(fullfile(out,'junit.xml')));
results=runner.run(suite);
save(fullfile(out,'test_results.mat'),'results');
summary=table(string({results.Name})',[results.Passed]',[results.Failed]', ...
    [results.Incomplete]',[results.Duration]', ...
    'VariableNames',{'Name','Passed','Failed','Incomplete','DurationSeconds'});
writetable(summary,fullfile(out,'test_results.csv'));
fprintf('TOTAL=%d PASSED=%d FAILED=%d INCOMPLETE=%d\n',numel(results),sum([results.Passed]),sum([results.Failed]),sum([results.Incomplete]));
assert(all([results.Passed]),'dtmf:TestsFailed','存在失败或未完成测试，请检查原始记录。');
end
