#!/bin/bash
set -e

REVISION="1.0.2"
CHANGE_LIST="-SNAPSHOT"
VERSION="${REVISION}${CHANGE_LIST}"
PACKAGE_NAME="automated-release-demo"
BUILD_DIR="build/deb"

echo "Building .deb package for version ${VERSION}"

rm -rf ${BUILD_DIR}
mkdir -p ${BUILD_DIR}/DEBIAN
mkdir -p ${BUILD_DIR}/opt/${PACKAGE_NAME}
mkdir -p ${BUILD_DIR}/usr/bin

cp target/${PACKAGE_NAME}-${VERSION}.jar ${BUILD_DIR}/opt/${PACKAGE_NAME}/

cat > ${BUILD_DIR}/DEBIAN/control << EOF
Package: ${PACKAGE_NAME}
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: all
Depends: openjdk-17-jre
Maintainer: galvagnimatteo <galvagni.matteo@protonmail.com>
Description: Automated Release Demo Application
 A simple Java application for testing automated releases.
EOF

cat > ${BUILD_DIR}/usr/bin/${PACKAGE_NAME} << 'EOF'
#!/bin/bash
java -jar /opt/automated-release-demo/automated-release-demo-*.jar "$@"
EOF

chmod +x ${BUILD_DIR}/usr/bin/${PACKAGE_NAME}

cat > ${BUILD_DIR}/DEBIAN/postinst << 'EOF'
#!/bin/bash
echo "automated-release-demo installed successfully!"
EOF

chmod +x ${BUILD_DIR}/DEBIAN/postinst

dpkg-deb --build ${BUILD_DIR} ${PACKAGE_NAME}_${VERSION}_all.deb

echo "✅ Package created: ${PACKAGE_NAME}_${VERSION}_all.deb"