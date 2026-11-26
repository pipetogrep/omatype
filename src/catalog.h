#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QNetworkAccessManager>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>

class Backend;

struct CatalogAxis {
    QString tag;
    qreal min = 0;
    qreal max = 0;
    qreal defaultValue = 0;
};

struct CatalogFile {
    QString filename;
    QString url;
    QString style;
    int weight = 400;
    bool italic = false;
    bool variable = false;
};

struct CatalogFamily {
    QString id;
    QString family;
    QString source;       // "google" | "indie"
    QString sourceLabel;  // "Google Fonts" | "Velvetyne Type Foundry" | ...
    QString foundry;
    QStringList designers;
    QString category;     // "Sans Serif" | "Serif" | "Display" | "Handwriting" | "Monospace"
    QString license;      // "SIL OFL 1.1" | "Apache 2.0" | ...
    QString description;
    QString homepage;
    QString repoUrl;
    QStringList subsets;
    QStringList styles;
    QList<int> weights;
    bool variable = false;
    bool isNoto = false;
    QList<CatalogAxis> axes;
    int popularity = 99999;
    int trending = 99999;
    QString dateAdded;
    QString previewUrl;
    QList<CatalogFile> files;
    QString licenseText;
    bool manifestLoaded = false;

    // Runtime state updated dynamically.
    QString previewFile;
    bool installed = false;
    bool installing = false;
    bool shortlisted = false;

    QString designersText() const { return designers.join(QStringLiteral(", ")); }
    QString weightRangeText() const;
    QString axesSummary() const;
};

class CatalogModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        FamilyRole,
        SourceRole,
        SourceLabelRole,
        FoundryRole,
        DesignersRole,
        DesignersTextRole,
        CategoryRole,
        LicenseRole,
        DescriptionRole,
        HomepageRole,
        RepoUrlRole,
        SubsetsRole,
        StylesRole,
        StyleCountRole,
        WeightRangeRole,
        VariableRole,
        AxesSummaryRole,
        PreviewFileRole,
        InstalledRole,
        InstallingRole,
        ShortlistedRole,
        PopularityRole,
        DateAddedRole,
    };

    explicit CatalogModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    void setEntries(QList<CatalogFamily> entries);
    void updateEntry(const QString &id, const CatalogFamily &updated, const QList<int> &roles = {});
    int indexOf(const QString &id) const;
    const QList<CatalogFamily> &entries() const { return m_entries; }

private:
    QList<CatalogFamily> m_entries;
    QHash<QString, int> m_rowById;
};

// Open-source font catalog engine: indexes Google Fonts (live metadata with
// 24h disk cache) + curated independent foundries (Velvetyne, Indestructible
// Type, League of Moveable Type, studio & developer typefaces), streams tiny
// subsetted TTF previews on demand, and performs 1-click installs directly to
// ~/.local/share/fonts/<Family>/ with fc-cache refresh.
class Catalog : public QObject {
    Q_OBJECT
    Q_PROPERTY(CatalogModel *model READ model CONSTANT)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countsChanged)
    Q_PROPERTY(int filteredCount READ filteredCount NOTIFY countsChanged)
    Q_PROPERTY(int googleCount READ googleCount NOTIFY countsChanged)
    Q_PROPERTY(int indieCount READ indieCount NOTIFY countsChanged)
    Q_PROPERTY(int shortlistCount READ shortlistCount NOTIFY shortlistChanged)
    Q_PROPERTY(int installedCatalogCount READ installedCatalogCount NOTIFY countsChanged)

    Q_PROPERTY(QString query READ query WRITE setQuery NOTIFY filterChanged)
    Q_PROPERTY(QString category READ category WRITE setCategory NOTIFY filterChanged)
    Q_PROPERTY(QString sourceFilter READ sourceFilter WRITE setSourceFilter NOTIFY filterChanged)
    Q_PROPERTY(bool variableOnly READ variableOnly WRITE setVariableOnly NOTIFY filterChanged)
    Q_PROPERTY(QString scriptFilter READ scriptFilter WRITE setScriptFilter NOTIFY filterChanged)
    Q_PROPERTY(QString sortBy READ sortBy WRITE setSortBy NOTIFY filterChanged)
    Q_PROPERTY(bool hideNoto READ hideNoto WRITE setHideNoto NOTIFY filterChanged)
    Q_PROPERTY(QString sampleText READ sampleText WRITE setSampleText NOTIFY sampleTextChanged)

    Q_PROPERTY(QString selectedId READ selectedId WRITE selectFamily NOTIFY selectionChanged)
    Q_PROPERTY(QVariantMap selectedFamily READ selectedFamily NOTIFY selectionChanged)
    Q_PROPERTY(bool loadingManifest READ loadingManifest NOTIFY manifestChanged)
    Q_PROPERTY(QVariantList selectedFiles READ selectedFiles NOTIFY manifestChanged)

    Q_PROPERTY(bool installingAny READ installingAny NOTIFY installStateChanged)
    Q_PROPERTY(QString installStatus READ installStatus NOTIFY installStateChanged)
    Q_PROPERTY(QVariantList shortlistItems READ shortlistItems NOTIFY shortlistChanged)

public:
    explicit Catalog(Backend *backend, QObject *parent = nullptr);

    CatalogModel *model() { return &m_model; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    int totalCount() const { return m_all.size(); }
    int filteredCount() const { return m_model.rowCount(); }
    int googleCount() const { return m_googleCount; }
    int indieCount() const { return m_indieCount; }
    int shortlistCount() const { return m_shortlist.size(); }
    int installedCatalogCount() const { return m_installedCatalogCount; }

    QString query() const { return m_query; }
    void setQuery(const QString &q);
    QString category() const { return m_category; }
    void setCategory(const QString &cat);
    QString sourceFilter() const { return m_sourceFilter; }
    void setSourceFilter(const QString &src);
    bool variableOnly() const { return m_variableOnly; }
    void setVariableOnly(bool on);
    QString scriptFilter() const { return m_scriptFilter; }
    void setScriptFilter(const QString &script);
    QString sortBy() const { return m_sortBy; }
    void setSortBy(const QString &sort);
    bool hideNoto() const { return m_hideNoto; }
    void setHideNoto(bool hide);
    QString sampleText() const { return m_sampleText; }
    void setSampleText(const QString &text);

    QString selectedId() const { return m_selectedId; }
    QVariantMap selectedFamily() const;
    bool loadingManifest() const { return m_loadingManifest; }
    QVariantList selectedFiles() const;

    bool installingAny() const { return !m_installingIds.isEmpty(); }
    QString installStatus() const { return m_installStatus; }
    QVariantList shortlistItems() const;

    // Pure helpers (also exercised by tests).
    static QString normalizeId(const QString &family);
    static QByteArray stripXssiPrefix(const QByteArray &raw);
    static QList<CatalogFamily> parseGoogleMetadata(const QByteArray &json);
    static QList<CatalogFamily> parseCuratedCatalog(const QByteArray &json);
    static bool parseGoogleDownloadManifest(const QByteArray &json, QList<CatalogFile> *files, QString *licenseText);
    static QString extractCssFontUrl(const QByteArray &css);
    static bool looksLikeFontFile(const QByteArray &bytes);
    static QString weightLabel(int weight, bool italic);

    // Headless / CLI blocking helpers.
    bool loadBlocking(bool forceRefresh = false);
    QList<CatalogFamily> searchFamilies(const QString &query, const QString &category = {}, const QString &source = {}, int limit = 50) const;
    const CatalogFamily *findByNameOrId(const QString &nameOrId) const;
    QString installFamilyBlocking(const QString &nameOrId, bool preferVariable = true, const QStringList &filenames = {}, QString *installedDir = nullptr, int *fileCount = nullptr);

    Q_INVOKABLE QUrl fileUrl(const QString &path) const { return QUrl::fromLocalFile(path); }
    Q_INVOKABLE void openUrl(const QString &url) const;

public slots:
    void load(bool forceRefresh = false);
    void syncInstalled();
    void requestPreview(const QString &id);
    void selectFamily(const QString &id);
    void installFamily(const QString &id, bool preferVariable = true, const QStringList &selectedFilenames = {});
    void uninstallFamily(const QString &id);
    void toggleShortlist(const QString &id);
    void clearShortlist();
    void installShortlist();
    void resetFilters();

signals:
    void loadingChanged();
    void errorChanged();
    void countsChanged();
    void filterChanged();
    void sampleTextChanged();
    void selectionChanged();
    void manifestChanged();
    void installStateChanged();
    void shortlistChanged();
    void previewReady(const QString &id, const QString &filePath);
    void installFinished(const QString &id, bool ok, const QString &message);

private:
    static QString cacheDir();
    static QString previewCacheDir();
    static QString googleCachePath();

    void loadCuratedFromQrc();
    void mergeCatalogs(const QList<CatalogFamily> &googleFamilies);
    void rebuildModel();
    void pumpPreviewQueue();
    void fetchGooglePreview(const QString &id, const QString &family, const QString &text, const QString &cachePath);
    void fetchDirectPreview(const QString &id, const QString &url, const QString &cachePath);
    void fetchGoogleManifest(const QString &id, std::function<void(bool)> callback = nullptr);
    void startInstallDownload(const QString &id, bool preferVariable, const QStringList &selectedFilenames);
    QString previewCachePath(const CatalogFamily &entry, const QString &text) const;
    QString previewTextKey() const;
    void saveShortlist();
    void loadShortlist();
    void setInstallStatus(const QString &msg);

    Backend *m_backend = nullptr;
    QNetworkAccessManager m_nam;
    CatalogModel m_model;

    QList<CatalogFamily> m_curated;
    QList<CatalogFamily> m_all;
    QHash<QString, int> m_indexById;

    bool m_loading = false;
    bool m_loadedOnce = false;
    QString m_error;
    int m_googleCount = 0;
    int m_indieCount = 0;
    int m_installedCatalogCount = 0;

    QString m_query;
    QString m_category;
    QString m_sourceFilter = QStringLiteral("all");
    bool m_variableOnly = false;
    QString m_scriptFilter;
    QString m_sortBy = QStringLiteral("popular");
    bool m_hideNoto = true;
    QString m_sampleText = QStringLiteral("The quick brown fox jumps over the lazy dog");

    QString m_selectedId;
    bool m_loadingManifest = false;

    // Preview queue (LIFO so visible cards load first).
    QStringList m_previewQueue;
    QSet<QString> m_previewInFlight;
    int m_activePreviews = 0;
    QTimer m_sampleDebounce;

    // Install tracking.
    QSet<QString> m_installingIds;
    QString m_installStatus;
    QStringList m_shortlist;

    static constexpr int kMaxConcurrentPreviews = 6;
    static constexpr qint64 kGoogleCacheTtlSeconds = 24 * 60 * 60;
};
