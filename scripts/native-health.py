#!/usr/bin/env python3
"""Read build/profile metadata without printing credentials or certificate data."""
import argparse, datetime, json, pathlib, plistlib, subprocess, sys
UTC=datetime.timezone.utc

def health(app, now=None):
    now=now or datetime.datetime.now(UTC)
    app=pathlib.Path(app)
    try:
        info=plistlib.loads((app/'Info.plist').read_bytes())
    except (OSError,plistlib.InvalidFileException):
        return {'ok':False,'reason':'No built app found. Run npm run ios:install on your Mac.'}
    result={'version':info.get('CFBundleShortVersionString'),'build':info.get('CFBundleVersion'),'bundle':info.get('CFBundleIdentifier'),'ok':False}
    if result['bundle']!='com.ediz.os':
        return {**result,'reason':'This is not the Ediz OS app.'}
    profile=app/'embedded.mobileprovision'
    try:
        decoded=subprocess.run(['openssl','cms','-verify','-inform','DER','-in',str(profile),'-noverify'],capture_output=True,timeout=10,check=True)
        data=plistlib.loads(decoded.stdout)
        expires=data['ExpirationDate'].replace(tzinfo=UTC)
    except (OSError,KeyError,ValueError,subprocess.SubprocessError,plistlib.InvalidFileException):
        return {**result,'reason':'Cannot read the signed-device profile. Rebuild with Xcode signing enabled.'}
    hours=(expires-now).total_seconds()/3600
    return {**result,'ok':hours>0,'personalTeam':bool(data.get('LocalProvision')),'expires':expires.isoformat(),'hoursRemaining':round(hours,1),'reason':'Profile has expired. Renew it in Xcode before installing.' if hours<=0 else 'Signed build is valid.'}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--app',required=True)
    parser.add_argument('--minimum-hours',type=float,default=0)
    parser.add_argument('--json',action='store_true')
    args=parser.parse_args();result=health(args.app)
    if result.get('ok') and result.get('hoursRemaining',0)<args.minimum_hours:
        result.update(ok=False,reason='Signing expires too soon. Renew the profile in Xcode before installing.')
    if args.json:print(json.dumps(result))
    else:
        print('Ediz OS native build:',str(result.get('version','unknown')),'('+str(result.get('build','?'))+')')
        print(result['reason'])
        if result.get('expires'):print('Signing expires:',result['expires'],'—',result['hoursRemaining'],'hours remaining')
        if result.get('personalTeam'):print('Free Personal Team signing lasts seven days. Connect your iPhone and refresh the build before expiry.')
    return 0 if result['ok'] else 1
if __name__=='__main__':sys.exit(main())
