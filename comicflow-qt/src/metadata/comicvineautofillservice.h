#pragma once

#include <QObject>
#include <QString>
#include <QVariantMap>

class QNetworkAccessManager;

class ComicVineAutofillService : public QObject
{
    Q_OBJECT

public:
    explicit ComicVineAutofillService(const QString &dataRoot, QObject *parent = nullptr);

    QVariantMap requestAutofillFromCache(const QVariantMap &seedValues);
    void requestAutofillAsync(int requestId, const QVariantMap &seedValues);
    QString configuredApiKey() const;
    QString saveApiKey(const QString &apiKey) const;
    void requestApiKeyValidationAsync(int requestId, const QString &apiKey);

signals:
    void autofillFinished(int requestId, QVariantMap result);
    void apiKeyValidationFinished(int requestId, QVariantMap result);

private:
    void emitAutofillFinishedLater(int requestId, const QVariantMap &result);
    void emitApiKeyValidationFinishedLater(int requestId, const QVariantMap &result);

    QString m_dataRoot;
    QNetworkAccessManager *m_networkAccessManager = nullptr;
};
