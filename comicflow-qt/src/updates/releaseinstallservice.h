#pragma once

#include <QObject>
#include <QString>

class ReleaseInstallService : public QObject
{
    Q_OBJECT

public:
    explicit ReleaseInstallService(QObject *parent = nullptr);

    Q_INVOKABLE QString installDownloadedRelease(const QString &packagePath);

private:
    QString validateInstallRequest(const QString &packagePath) const;
    QString ensureHelperRoot(QString &helperRootOut) const;
    QString writeHelperScript(const QString &helperRootPath) const;
    QString helperScriptBody() const;
};
