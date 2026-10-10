import importlib.util, pathlib, plistlib, tempfile, unittest, datetime
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('native_health',pathlib.Path(__file__).with_name('native-health.py'))
health_module=importlib.util.module_from_spec(spec);spec.loader.exec_module(health_module)
class HealthTests(unittest.TestCase):
    def app(self,folder,bundle='com.ediz.os'):
        app=pathlib.Path(folder)/'App.app';app.mkdir();(app/'Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':bundle,'CFBundleShortVersionString':'1.0','CFBundleVersion':'1'}));return app
    def testExpiredProfileIsRejectedAndNoPrivateProfileFieldsAreReported(self):
        now=datetime.datetime(2026,10,9,tzinfo=datetime.timezone.utc)
        profile=plistlib.dumps({'ExpirationDate':datetime.datetime(2026,10,8),'LocalProvision':True,'DeveloperCertificates':['private certificate'],'ProvisionedDevices':['private device']})
        with tempfile.TemporaryDirectory() as folder,patch.object(health_module.subprocess,'run') as run:
            run.return_value.stdout=profile
            result=health_module.health(self.app(folder),now)
            self.assertFalse(result['ok']);self.assertLess(result['hoursRemaining'],0)
            self.assertNotIn('DeveloperCertificates',result);self.assertNotIn('ProvisionedDevices',result)
    def testValidProfileHasActualRemainingTime(self):
        now=datetime.datetime(2026,10,9,tzinfo=datetime.timezone.utc)
        with tempfile.TemporaryDirectory() as folder,patch.object(health_module.subprocess,'run') as run:
            run.return_value.stdout=plistlib.dumps({'ExpirationDate':datetime.datetime(2026,10,16),'LocalProvision':True})
            result=health_module.health(self.app(folder),now)
            self.assertTrue(result['ok']);self.assertEqual(result['hoursRemaining'],168)
    def testWrongAppIsRejectedBeforeReadingSigningData(self):
        with tempfile.TemporaryDirectory() as folder,patch.object(health_module.subprocess,'run') as run:
            self.assertFalse(health_module.health(self.app(folder,'other.app'))['ok']);run.assert_not_called()
    def testMissingBuildDoesNotPretendToBeValid(self):
        with tempfile.TemporaryDirectory() as folder:self.assertFalse(health_module.health(folder)['ok'])
if __name__=='__main__':unittest.main()
