"""Writes licenses text into a file."""

import argparse
import codecs
import html
import json


def _get_licenses(licenses_info):
    with codecs.open(licenses_info, encoding='utf-8') as licenses_file:
        return json.loads(licenses_file.read())


def _write_licenses(out, licenses):
    out.write("""\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>PreferenceSpecifiers</key>
	<array>
		<dict>
			<key>FooterText</key>
			<string>This application makes use of the following third party libraries:</string>
			<key>Title</key>
			<string>Acknowledgements</string>
			<key>Type</key>
			<string>PSGroupSpecifier</string>
		</dict>
""")

    for lic in licenses:
        path = lic['license_text']
        with codecs.open(path, encoding='utf-8') as license_file:
            out.write("""\
		<dict>
			<key>FooterText</key>
			<string>{license_text}</string>
			<key>Title</key>
			<string>{package_name}</string>
			<key>License</key>
			<string>{license_kind}</string>
			<key>Type</key>
			<string>PSGroupSpecifier</string>
		</dict>
""".format(
                license_text=html.escape(license_file.read()),
                license_kind=lic['license_kinds'][0]['name'],
                package_name=lic['package_name'],
            ))

    out.write("""\
	</array>
	<key>StringsTable</key>
	<string>Acknowledgements</string>
	<key>Title</key>
	<string>Acknowledgements</string>
</dict>
</plist>
""")


def main():
    parser = argparse.ArgumentParser(
        description='Writes licenses text to a file given licenses info')

    parser.add_argument('--licenses_info',
                        help='path to JSON file containing all license data')
    parser.add_argument('--out', help='output file of all license files')
    args = parser.parse_args()

    licenses = _get_licenses(args.licenses_info)
    err = 0
    with codecs.open(args.out, mode='w', encoding='utf-8') as out:
        _write_licenses(out, licenses)
    return err


if __name__ == '__main__':
    main()
