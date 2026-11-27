#!/usr/bin/env python3
"""Exercise the embedded transaction helper on real files in an isolated fixture.
Only the /volumeN test prefix and root-identity checks are substituted. Production
source is unchanged; this is not validation on a DSM volume or SMB server.
"""
import os,re,sys,tempfile,pathlib,subprocess,json,stat
source=(pathlib.Path(__file__).resolve().parents[1]/'lin/modules/SynologyOffice.sh').read_text()
code=source.split('"$py" - "$mode" "$source" "$destination" <<\'PY\'\n',1)[1].split('\nPY\n',1)[0]
def run(code,mode,path,success=True):
 r=subprocess.run([sys.executable,'-c',code,mode,str(path),''],capture_output=True,text=True,timeout=5)
 if success and r.returncode:raise AssertionError(r.stderr+r.stdout)
 if not success and not r.returncode:raise AssertionError('Unexpected successful transaction')
 return r.stdout.strip()
with tempfile.TemporaryDirectory() as directory:
 root=pathlib.Path(directory)
 code=code.replace("r'^(/volume[0-9]+)/'",repr('^('+re.escape(str(root))+'/volume[0-9]+)/'))
 code=code.replace("r'^/volume[0-9]+/@d0xd-owner-quarantine/[^/]+/manifest\\.json$'",repr('^'+re.escape(str(root))+'/volume[0-9]+/@d0xd-owner-quarantine/[^/]+/manifest\\.json$'))
 code=code.replace('os.geteuid()!=0','False').replace('s.st_uid!=0','s.st_uid!=os.getuid()').replace('ms.st_uid!=0','ms.st_uid!=os.getuid()')
 volume=root/'volume1';share=volume/'Share with spaces ñ';share.mkdir(parents=True)
 original=share/'report & [2026].xlsx';original.write_bytes(b'ORIGINAL DOCUMENT MUST NOT CHANGE')
 owner=share/'~$report & [2026].xlsx';owner.write_bytes(b'Office User');owner.chmod(0o640)
 before=owner.stat()
 run(code,'prepare',owner)
 assert not (volume/'@d0xd-owner-quarantine').exists(),'Prepare mutated filesystem'
 result=run(code,'quarantine',owner)
 manifest=pathlib.Path(result.split('Manifest: ',1)[1]);record=json.loads(manifest.read_text());payload=pathlib.Path(record['payload'])
 assert not owner.exists() and payload.read_bytes()==b'Office User'
 assert payload.stat().st_ino==before.st_ino and payload.stat().st_mtime_ns==before.st_mtime_ns
 assert stat.S_IMODE(payload.stat().st_mode)==0o640
 assert stat.S_IMODE(manifest.stat().st_mode)==0o600
 assert original.read_bytes()==b'ORIGINAL DOCUMENT MUST NOT CHANGE'
 owner.write_bytes(b'NEW OWNER FILE')
 run(code,'restore',manifest,False)
 assert owner.read_bytes()==b'NEW OWNER FILE' and payload.exists(),'Collision was destructive'
 owner.unlink();run(code,'restore',manifest)
 assert owner.read_bytes()==b'Office User' and not payload.exists()
 assert manifest.exists(),'Recovery manifest unexpectedly removed'
 # A reused transaction ID cannot overwrite a destination/manifest.
 fixed=code.replace('uuid.uuid4().hex',"'fixed'").replace("time.strftime('%Y%m%dT%H%M%S')","'fixed'")
 one=share/'~$one.xlsx';two=share/'~$two.xlsx';one.write_bytes(b'one');two.write_bytes(b'two')
 run(fixed,'quarantine',one);run(fixed,'quarantine',two,False)
 assert two.read_bytes()==b'two'
 # Symlinks, hard links and wrong filename types cannot be moved.
 alias=share/'~$alias.xlsx';alias.symlink_to(original);run(code,'prepare',alias,False);alias.unlink()
 os.link(original,alias);run(code,'prepare',alias,False);alias.unlink()
 run(code,'prepare',original,False)
 # Payload tampering prevents restore.
 result=run(code,'quarantine',owner);manifest=pathlib.Path(result.split('Manifest: ',1)[1]);payload=pathlib.Path(json.loads(manifest.read_text())['payload']);payload.write_bytes(b'TAMPERED')
 run(code,'restore',manifest,False)
 assert original.read_bytes()==b'ORIGINAL DOCUMENT MUST NOT CHANGE'
 print('PASS: Transaction fixture: no-overwrite quarantine/restore, metadata, collisions, symlinks, hard links, payload tampering and unchanged original document')
