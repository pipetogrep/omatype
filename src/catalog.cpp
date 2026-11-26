#include "catalog.h"
#include "backend.h"

#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSettings>
#include <QStandardPaths>
#include <QUrlQuery>
#include <algorithm>
#include <filesystem>
#include <system_error>

namespace {

constexpr const char *kGoogleMetadataUrl = "https://fonts.google.com/metadata/fonts";
constexpr const char *kGoogleCss2Base = "https://fonts.googleapis.com/css2";
constexpr const char *kGoogleDownloadListBase = "https://fonts.google.com/download/list";
// Short UA so Google Fonts CSS2 returns direct TrueType (.ttf) URLs rather than woff2.
constexpr const char *kTtfUserAgent = "Mozilla/5.0";

QString normaliseCategory(const QString &raw) {
    const QString c = raw.trimmed().toLower();
    if (c == QLatin1String("sans serif") || c == QLatin1String("sans-serif") || c == QLatin1String("sans"))
        return QStringLiteral("Sans Serif");
    if (c == QLatin1String("serif"))
        return QStringLiteral("Serif");
    if (c == QLatin1String("display"))
        return QStringLiteral("Display");
    if (c == QLatin1String("handwriting") || c == QLatin1String("script"))
        return QStringLiteral("Handwriting");
    if (c == QLatin1String("monospace") || c == QLatin1String("mono"))
        return QStringLiteral("Monospace");
    return raw.trimmed().isEmpty() ? QStringLiteral("Sans Serif") : raw.trimmed();
}

int parseWeightKey(const QString &key, bool *italic = nullptr) {
    QString s = key.trimmed().toLower();
    const bool it = s.endsWith(QLatin1Char('i')) || s.contains(QStringLiteral("italic"));
    if (italic) *italic = it;
    if (s.endsWith(QLatin1Char('i'))) s.chop(1);
    bool ok = false;
    const int w = s.toInt(&ok);
    return ok ? w : 400;
}

int inferWeightFromFilename(const QString &filename, bool *italic = nullptr) {
    const QString lower = filename.toLower();
    if (italic) *italic = lower.contains(QStringLiteral("italic")) || lower.contains(QStringLiteral("oblique"));
    if (lower.contains(QStringLiteral("thin")) || lower.contains(QStringLiteral("hairline"))) return 100;
    if (lower.contains(QStringLiteral("extralight")) || lower.contains(QStringLiteral("ultralight"))) return 200;
    if (lower.contains(QStringLiteral("light"))) return 300;
    if (lower.contains(QStringLiteral("medium"))) return 500;
    if (lower.contains(QStringLiteral("semibold")) || lower.contains(QStringLiteral("demibold"))) return 600;
    if (lower.contains(QStringLiteral("extrabold")) || lower.contains(QStringLiteral("ultrabold"))) return 800;
    if (lower.contains(QStringLiteral("black")) || lower.contains(QStringLiteral("heavy"))) return 900;
    if (lower.contains(QStringLiteral("bold"))) return 700;
    return 400;
}

bool isDesktopFontFilename(const QString &name) {
    const QString lower = name.toLower();
    return lower.endsWith(QStringLiteral(".ttf"))
        || lower.endsWith(QStringLiteral(".otf"))
        || lower.endsWith(QStringLiteral(".ttc"))
        || lower.endsWith(QStringLiteral(".otc"));
}

} // namespace

// ── CatalogFamily helpers ───────────────────────────────────────────────────

QString CatalogFamily::weightRangeText() const {
    if (weights.isEmpty()) {
        for (const CatalogAxis &a : axes) {
            if (a.tag == QLatin1String("wght"))
                return QStringLiteral("%1–%2").arg(qRound(a.min)).arg(qRound(a.max));
        }
        return {};
    }
    const auto mm = std::minmax_element(weights.cbegin(), weights.cend());
    if (*mm.first == *mm.second) return QString::number(*mm.first);
    return QStringLiteral("%1–%2").arg(*mm.first).arg(*mm.second);
}

QString CatalogFamily::axesSummary() const {
    QStringList parts;
    for (const CatalogAxis &a : axes)
        parts.append(QStringLiteral("%1 %2–%3").arg(a.tag).arg(qRound(a.min)).arg(qRound(a.max)));
    return parts.join(QStringLiteral(" · "));
}

// ── CatalogModel ────────────────────────────────────────────────────────────

CatalogModel::CatalogModel(QObject *parent) : QAbstractListModel(parent) {}

int CatalogModel::rowCount(const QModelIndex &parent) const {
    return parent.isValid() ? 0 : m_entries.size();
}

QVariant CatalogModel::data(const QModelIndex &index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= m_entries.size()) return {};
    const CatalogFamily &e = m_entries.at(index.row());
    switch (role) {
    case IdRole: return e.id;
    case FamilyRole: return e.family;
    case SourceRole: return e.source;
    case SourceLabelRole: return e.sourceLabel;
    case FoundryRole: return e.foundry;
    case DesignersRole: return e.designers;
    case DesignersTextRole: return e.designersText();
    case CategoryRole: return e.category;
    case LicenseRole: return e.license;
    case DescriptionRole: return e.description;
    case HomepageRole: return e.homepage;
    case RepoUrlRole: return e.repoUrl;
    case SubsetsRole: return e.subsets;
    case StylesRole: return e.styles;
    case StyleCountRole: return std::max<int>(1, e.styles.size());
    case WeightRangeRole: return e.weightRangeText();
    case VariableRole: return e.variable;
    case AxesSummaryRole: return e.axesSummary();
    case PreviewFileRole: return e.previewFile;
    case InstalledRole: return e.installed;
    case InstallingRole: return e.installing;
    case ShortlistedRole: return e.shortlisted;
    case PopularityRole: return e.popularity;
    case DateAddedRole: return e.dateAdded;
    }
    return {};
}

QHash<int, QByteArray> CatalogModel::roleNames() const {
    return {
        {IdRole, "id"},
        {FamilyRole, "family"},
        {SourceRole, "source"},
        {SourceLabelRole, "sourceLabel"},
        {FoundryRole, "foundry"},
        {DesignersRole, "designers"},
        {DesignersTextRole, "designersText"},
        {CategoryRole, "category"},
        {LicenseRole, "license"},
        {DescriptionRole, "description"},
        {HomepageRole, "homepage"},
        {RepoUrlRole, "repoUrl"},
        {SubsetsRole, "subsets"},
        {StylesRole, "styles"},
        {StyleCountRole, "styleCount"},
        {WeightRangeRole, "weightRange"},
        {VariableRole, "variable"},
        {AxesSummaryRole, "axesSummary"},
        {PreviewFileRole, "previewFile"},
        {InstalledRole, "installed"},
        {InstallingRole, "installing"},
        {ShortlistedRole, "shortlisted"},
        {PopularityRole, "popularity"},
        {DateAddedRole, "dateAdded"},
    };
}

void CatalogModel::setEntries(QList<CatalogFamily> entries) {
    beginResetModel();
    m_entries = std::move(entries);
    m_rowById.clear();
    m_rowById.reserve(m_entries.size());
    for (int i = 0; i < m_entries.size(); ++i) m_rowById.insert(m_entries.at(i).id, i);
    endResetModel();
}

void CatalogModel::updateEntry(const QString &id, const CatalogFamily &updated, const QList<int> &roles) {
    const auto it = m_rowById.constFind(id);
    if (it == m_rowById.cend()) return;
    const int row = it.value();
    m_entries[row] = updated;
    const QModelIndex idx = index(row, 0);
    emit dataChanged(idx, idx, roles);
}

int CatalogModel::indexOf(const QString &id) const {
    return m_rowById.value(id, -1);
}

// ── Catalog static helpers ──────────────────────────────────────────────────

QString Catalog::normalizeId(const QString &family) {
    QString out;
    out.reserve(family.size());
    bool lastDash = false;
    for (const QChar ch : family.trimmed().toLower()) {
        if (ch.isLetterOrNumber()) {
            out.append(ch);
            lastDash = false;
        } else if (!lastDash && !out.isEmpty()) {
            out.append(QLatin1Char('-'));
            lastDash = true;
        }
    }
    while (out.endsWith(QLatin1Char('-'))) out.chop(1);
    return out;
}

QByteArray Catalog::stripXssiPrefix(const QByteArray &raw) {
    int start = 0;
    while (start < raw.size() && (raw.at(start) == ' ' || raw.at(start) == '\t' || raw.at(start) == '\r' || raw.at(start) == '\n'))
        ++start;
    if (raw.mid(start, 4) == ")]}'") {
        const int nl = raw.indexOf('\n', start);
        if (nl >= 0) return raw.mid(nl + 1);
        return raw.mid(start + 4);
    }
    return raw;
}

QString Catalog::weightLabel(int weight, bool italic) {
    QString name;
    if (weight <= 150) name = QStringLiteral("Thin");
    else if (weight <= 250) name = QStringLiteral("ExtraLight");
    else if (weight <= 350) name = QStringLiteral("Light");
    else if (weight <= 450) name = QStringLiteral("Regular");
    else if (weight <= 550) name = QStringLiteral("Medium");
    else if (weight <= 650) name = QStringLiteral("SemiBold");
    else if (weight <= 750) name = QStringLiteral("Bold");
    else if (weight <= 850) name = QStringLiteral("ExtraBold");
    else name = QStringLiteral("Black");
    if (italic) name = (name == QLatin1String("Regular")) ? QStringLiteral("Italic") : (name + QStringLiteral(" Italic"));
    return name;
}

QList<CatalogFamily> Catalog::parseGoogleMetadata(const QByteArray &json) {
    QList<CatalogFamily> out;
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(stripXssiPrefix(json), &pe);
    if (pe.error != QJsonParseError::NoError || !doc.isObject()) return out;

    const QJsonArray list = doc.object().value(QStringLiteral("familyMetadataList")).toArray();
    out.reserve(list.size());
    for (const QJsonValue &v : list) {
        const QJsonObject o = v.toObject();
        const QString family = o.value(QStringLiteral("family")).toString().trimmed();
        if (family.isEmpty()) continue;

        CatalogFamily e;
        e.id = normalizeId(family);
        e.family = family;
        e.source = QStringLiteral("google");
        e.sourceLabel = QStringLiteral("Google Fonts");
        e.foundry = QStringLiteral("Google Fonts");
        e.category = normaliseCategory(o.value(QStringLiteral("category")).toString());
        e.license = QStringLiteral("SIL OFL 1.1");
        e.homepage = QStringLiteral("https://fonts.google.com/specimen/") + QString::fromUtf8(QUrl::toPercentEncoding(family));
        e.repoUrl = QStringLiteral("https://github.com/google/fonts");
        e.popularity = o.value(QStringLiteral("popularity")).toInt(99999);
        e.trending = o.value(QStringLiteral("trending")).toInt(99999);
        e.dateAdded = o.value(QStringLiteral("dateAdded")).toString();
        e.isNoto = o.value(QStringLiteral("isNoto")).toBool(family.startsWith(QStringLiteral("Noto "), Qt::CaseInsensitive));

        for (const QJsonValue &dv : o.value(QStringLiteral("designers")).toArray()) {
            const QString d = dv.toString().trimmed();
            if (!d.isEmpty() && !e.designers.contains(d)) e.designers.append(d);
        }
        for (const QJsonValue &sv : o.value(QStringLiteral("subsets")).toArray()) {
            const QString s = sv.toString().trimmed();
            if (!s.isEmpty() && s != QLatin1String("menu")) e.subsets.append(s);
        }
        for (const QJsonValue &av : o.value(QStringLiteral("axes")).toArray()) {
            const QJsonObject ao = av.toObject();
            CatalogAxis ax;
            ax.tag = ao.value(QStringLiteral("tag")).toString();
            ax.min = ao.value(QStringLiteral("min")).toDouble();
            ax.max = ao.value(QStringLiteral("max")).toDouble();
            ax.defaultValue = ao.value(QStringLiteral("defaultValue")).toDouble();
            if (!ax.tag.isEmpty()) e.axes.append(ax);
        }
        e.variable = !e.axes.isEmpty();

        const QJsonObject fontsObj = o.value(QStringLiteral("fonts")).toObject();
        QList<QPair<int, bool>> stylePairs;
        for (auto it = fontsObj.constBegin(); it != fontsObj.constEnd(); ++it) {
            bool italic = false;
            const int w = parseWeightKey(it.key(), &italic);
            stylePairs.append({w, italic});
            if (!e.weights.contains(w)) e.weights.append(w);
        }
        std::sort(e.weights.begin(), e.weights.end());
        std::sort(stylePairs.begin(), stylePairs.end(), [](const auto &a, const auto &b) {
            if (a.first != b.first) return a.first < b.first;
            return !a.second && b.second;
        });
        for (const auto &p : stylePairs)
            e.styles.append(weightLabel(p.first, p.second));

        out.append(std::move(e));
    }
    return out;
}

QList<CatalogFamily> Catalog::parseCuratedCatalog(const QByteArray &json) {
    QList<CatalogFamily> out;
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(json, &pe);
    if (pe.error != QJsonParseError::NoError || !doc.isObject()) return out;

    const QJsonArray list = doc.object().value(QStringLiteral("families")).toArray();
    out.reserve(list.size());
    int rank = 1;
    for (const QJsonValue &v : list) {
        const QJsonObject o = v.toObject();
        const QString family = o.value(QStringLiteral("family")).toString().trimmed();
        if (family.isEmpty()) continue;

        CatalogFamily e;
        e.id = o.value(QStringLiteral("id")).toString().trimmed();
        if (e.id.isEmpty()) e.id = normalizeId(family);
        e.family = family;
        e.source = QStringLiteral("indie");
        e.foundry = o.value(QStringLiteral("foundry")).toString().trimmed();
        e.sourceLabel = o.value(QStringLiteral("sourceLabel")).toString().trimmed();
        if (e.sourceLabel.isEmpty()) e.sourceLabel = e.foundry.isEmpty() ? QStringLiteral("Open Source") : e.foundry;
        e.category = normaliseCategory(o.value(QStringLiteral("category")).toString());
        e.license = o.value(QStringLiteral("license")).toString(QStringLiteral("SIL OFL 1.1"));
        e.description = o.value(QStringLiteral("description")).toString();
        e.homepage = o.value(QStringLiteral("homepage")).toString();
        e.repoUrl = o.value(QStringLiteral("repoUrl")).toString();
        e.previewUrl = o.value(QStringLiteral("previewUrl")).toString();
        e.variable = o.value(QStringLiteral("variable")).toBool(false);
        e.dateAdded = o.value(QStringLiteral("dateAdded")).toString(QStringLiteral("2026-01-01"));
        e.popularity = rank++;
        e.trending = e.popularity;
        e.manifestLoaded = true;

        for (const QJsonValue &dv : o.value(QStringLiteral("designers")).toArray()) {
            const QString d = dv.toString().trimmed();
            if (!d.isEmpty()) e.designers.append(d);
        }
        for (const QJsonValue &sv : o.value(QStringLiteral("subsets")).toArray()) {
            const QString s = sv.toString().trimmed();
            if (!s.isEmpty()) e.subsets.append(s);
        }
        if (e.subsets.isEmpty()) e.subsets.append(QStringLiteral("latin"));

        for (const QJsonValue &av : o.value(QStringLiteral("axes")).toArray()) {
            const QJsonObject ao = av.toObject();
            CatalogAxis ax;
            ax.tag = ao.value(QStringLiteral("tag")).toString();
            ax.min = ao.value(QStringLiteral("min")).toDouble();
            ax.max = ao.value(QStringLiteral("max")).toDouble();
            ax.defaultValue = ao.value(QStringLiteral("defaultValue")).toDouble();
            if (!ax.tag.isEmpty()) e.axes.append(ax);
        }

        for (const QJsonValue &fv : o.value(QStringLiteral("files")).toArray()) {
            const QJsonObject fo = fv.toObject();
            CatalogFile cf;
            cf.filename = fo.value(QStringLiteral("filename")).toString();
            cf.url = fo.value(QStringLiteral("url")).toString();
            cf.style = fo.value(QStringLiteral("style")).toString();
            cf.weight = fo.value(QStringLiteral("weight")).toInt(400);
            cf.italic = fo.value(QStringLiteral("italic")).toBool(false);
            cf.variable = fo.value(QStringLiteral("variable")).toBool(false);
            if (!cf.url.isEmpty() && !cf.filename.isEmpty()) {
                e.files.append(cf);
                if (!e.weights.contains(cf.weight)) e.weights.append(cf.weight);
                if (!cf.style.isEmpty() && !e.styles.contains(cf.style)) e.styles.append(cf.style);
            }
        }
        for (const QJsonValue &stv : o.value(QStringLiteral("styles")).toArray()) {
            const QString st = stv.toString().trimmed();
            if (!st.isEmpty() && !e.styles.contains(st)) e.styles.append(st);
        }
        std::sort(e.weights.begin(), e.weights.end());
        if (e.previewUrl.isEmpty() && !e.files.isEmpty()) e.previewUrl = e.files.first().url;

        out.append(std::move(e));
    }
    return out;
}

bool Catalog::parseGoogleDownloadManifest(const QByteArray &json, QList<CatalogFile> *files, QString *licenseText) {
    QJsonParseError pe;
    const QJsonDocument doc = QJsonDocument::fromJson(stripXssiPrefix(json), &pe);
    if (pe.error != QJsonParseError::NoError || !doc.isObject()) return false;

    const QJsonObject manifest = doc.object().value(QStringLiteral("manifest")).toObject();
    if (manifest.isEmpty()) return false;

    if (licenseText) {
        for (const QJsonValue &v : manifest.value(QStringLiteral("files")).toArray()) {
            const QJsonObject o = v.toObject();
            const QString name = o.value(QStringLiteral("filename")).toString();
            if (name.contains(QStringLiteral("OFL"), Qt::CaseInsensitive)
                || name.contains(QStringLiteral("LICENSE"), Qt::CaseInsensitive)
                || name.contains(QStringLiteral("UFL"), Qt::CaseInsensitive)) {
                *licenseText = o.value(QStringLiteral("contents")).toString();
                break;
            }
        }
    }

    if (files) {
        files->clear();
        for (const QJsonValue &v : manifest.value(QStringLiteral("fileRefs")).toArray()) {
            const QJsonObject o = v.toObject();
            const QString rawPath = o.value(QStringLiteral("filename")).toString();
            const QString url = o.value(QStringLiteral("url")).toString();
            const QString base = QFileInfo(rawPath).fileName();
            if (url.isEmpty() || !isDesktopFontFilename(base)) continue;

            CatalogFile cf;
            cf.filename = base;
            cf.url = url;
            cf.variable = !rawPath.startsWith(QStringLiteral("static/"))
                       && (base.contains(QStringLiteral("VariableFont"), Qt::CaseInsensitive)
                           || base.contains(QLatin1Char('[')));
            bool italic = false;
            cf.weight = inferWeightFromFilename(base, &italic);
            cf.italic = italic;
            cf.style = cf.variable
                ? (italic ? QStringLiteral("Variable Italic") : QStringLiteral("Variable"))
                : weightLabel(cf.weight, italic);
            files->append(cf);
        }
        // Sort variable files first, then by weight ascending, roman before italic.
        std::sort(files->begin(), files->end(), [](const CatalogFile &a, const CatalogFile &b) {
            if (a.variable != b.variable) return a.variable;
            if (a.weight != b.weight) return a.weight < b.weight;
            return !a.italic && b.italic;
        });
    }
    return true;
}

QString Catalog::extractCssFontUrl(const QByteArray &css) {
    static const QRegularExpression re(QStringLiteral("url\\(([^)\\s'\"]+)\\)"));
    const QRegularExpressionMatch m = re.match(QString::fromUtf8(css));
    return m.hasMatch() ? m.captured(1) : QString();
}

bool Catalog::looksLikeFontFile(const QByteArray &bytes) {
    if (bytes.size() < 12) return false;
    const QByteArray sig = bytes.left(4);
    return sig == QByteArray("\x00\x01\x00\x00", 4)
        || sig == "OTTO"
        || sig == "true"
        || sig == "ttcf";
}

// ── Catalog paths ───────────────────────────────────────────────────────────

QString Catalog::cacheDir() {
    QString base = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
    if (base.isEmpty()) base = QDir::homePath() + QStringLiteral("/.cache/omatype");
    QDir().mkpath(base);
    return base;
}

QString Catalog::previewCacheDir() {
    const QString d = cacheDir() + QStringLiteral("/previews");
    QDir().mkpath(d);
    return d;
}

QString Catalog::googleCachePath() {
    return cacheDir() + QStringLiteral("/google-metadata.json");
}

// ── Catalog lifecycle ───────────────────────────────────────────────────────

Catalog::Catalog(Backend *backend, QObject *parent) : QObject(parent), m_backend(backend) {
    loadShortlist();
    loadCuratedFromQrc();

    m_sampleDebounce.setSingleShot(true);
    m_sampleDebounce.setInterval(260);
    connect(&m_sampleDebounce, &QTimer::timeout, this, [this] {
        // Clear cached Google preview bindings for the old sample text so visible
        // cards lazily request the new subsetted TTF for the edited text.
        m_previewQueue.clear();
        for (CatalogFamily &e : m_all) {
            if (e.source == QLatin1String("google") && !e.installed) {
                const QString path = previewCachePath(e, previewTextKey());
                e.previewFile = QFileInfo::exists(path) ? path : QString();
            }
        }
        rebuildModel();
        if (!m_selectedId.isEmpty()) emit selectionChanged();
    });

    if (m_backend) {
        connect(m_backend, &Backend::scanFinished, this, &Catalog::syncInstalled);
    }
}

void Catalog::loadCuratedFromQrc() {
    QFile f(QStringLiteral(":/data/curated-catalog.json"));
    if (f.open(QIODevice::ReadOnly)) {
        m_curated = parseCuratedCatalog(f.readAll());
    }
    mergeCatalogs({});
}

void Catalog::load(bool forceRefresh) {
    if (m_loading) return;

    const QString cachePath = googleCachePath();
    const QFileInfo fi(cachePath);
    if (!forceRefresh && fi.exists() && fi.size() > 1024) {
        const qint64 age = fi.lastModified().secsTo(QDateTime::currentDateTime());
        if (age >= 0 && age < kGoogleCacheTtlSeconds) {
            QFile f(cachePath);
            if (f.open(QIODevice::ReadOnly)) {
                const auto google = parseGoogleMetadata(f.readAll());
                if (!google.isEmpty()) {
                    m_loadedOnce = true;
                    m_error.clear();
                    emit errorChanged();
                    mergeCatalogs(google);
                    return;
                }
            }
        }
    }

    m_loading = true;
    m_error.clear();
    emit loadingChanged();
    emit errorChanged();

    QNetworkRequest req{QUrl(QString::fromLatin1(kGoogleMetadataUrl))};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Omatype/0.2"));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setTransferTimeout(20000);

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, cachePath] {
        reply->deleteLater();
        m_loading = false;
        emit loadingChanged();

        if (reply->error() != QNetworkReply::NoError) {
            // Fall back to stale cache if present.
            QFile f(cachePath);
            if (f.open(QIODevice::ReadOnly)) {
                const auto cached = parseGoogleMetadata(f.readAll());
                if (!cached.isEmpty()) {
                    mergeCatalogs(cached);
                    m_error = tr("Showing cached catalog (%1)").arg(reply->errorString());
                    emit errorChanged();
                    return;
                }
            }
            m_error = tr("Could not reach Google Fonts: %1. Showing curated indie catalog.").arg(reply->errorString());
            emit errorChanged();
            return;
        }

        const QByteArray raw = reply->readAll();
        const auto google = parseGoogleMetadata(raw);
        if (google.isEmpty()) {
            m_error = tr("Google Fonts metadata could not be parsed.");
            emit errorChanged();
            return;
        }

        QSaveFile sf(cachePath);
        if (sf.open(QIODevice::WriteOnly)) {
            sf.write(raw);
            sf.commit();
        }
        m_loadedOnce = true;
        m_error.clear();
        emit errorChanged();
        mergeCatalogs(google);
    });
}

bool Catalog::loadBlocking(bool forceRefresh) {
    if (m_loadedOnce && !forceRefresh && m_googleCount > 0) return true;
    QEventLoop loop;
    connect(this, &Catalog::loadingChanged, &loop, [&] {
        if (!m_loading) loop.quit();
    });
    load(forceRefresh);
    if (m_loading) loop.exec();
    return !m_all.isEmpty();
}

void Catalog::mergeCatalogs(const QList<CatalogFamily> &googleFamilies) {
    m_all.clear();
    m_indexById.clear();
    m_googleCount = 0;
    m_indieCount = 0;

    // Curated indie foundries first so their rich descriptions & direct URLs
    // are always present; Google Fonts merges in without duplicating by id.
    QHash<QString, int> seen;
    for (CatalogFamily e : m_curated) {
        e.shortlisted = m_shortlist.contains(e.id);
        const QString cp = previewCachePath(e, previewTextKey());
        if (QFileInfo::exists(cp)) e.previewFile = cp;
        seen.insert(e.id, m_all.size());
        m_indexById.insert(e.id, m_all.size());
        m_all.append(std::move(e));
        ++m_indieCount;
    }

    for (CatalogFamily e : googleFamilies) {
        if (seen.contains(e.id)) {
            // Enrich curated entry with Google popularity if it's also on Google Fonts.
            continue;
        }
        e.shortlisted = m_shortlist.contains(e.id);
        const QString cp = previewCachePath(e, previewTextKey());
        if (QFileInfo::exists(cp)) e.previewFile = cp;
        m_indexById.insert(e.id, m_all.size());
        m_all.append(std::move(e));
        if (!m_hideNoto || !m_all.last().isNoto) ++m_googleCount;
    }

    syncInstalled();
    rebuildModel();
    emit shortlistChanged();
    if (!m_selectedId.isEmpty()) emit selectionChanged();
}

void Catalog::syncInstalled() {
    QHash<QString, QString> installedRepById;
    if (m_backend) {
        for (const FontFamily &f : m_backend->allFamilies()) {
            const QString id = normalizeId(f.name);
            const QString rep = f.representative();
            installedRepById.insert(id, rep);
            for (const QString &member : f.members)
                installedRepById.insert(normalizeId(member), rep);
        }
    }

    m_installedCatalogCount = 0;
    for (CatalogFamily &e : m_all) {
        const auto it = installedRepById.constFind(e.id);
        const bool wasInstalled = e.installed;
        e.installed = (it != installedRepById.cend());
        if (e.installed) {
            ++m_installedCatalogCount;
            if (!it.value().isEmpty()) e.previewFile = it.value();
        } else if (wasInstalled && e.source == QLatin1String("google")) {
            const QString cp = previewCachePath(e, previewTextKey());
            e.previewFile = QFileInfo::exists(cp) ? cp : QString();
        }
        if (wasInstalled != e.installed) {
            m_model.updateEntry(e.id, e, {CatalogModel::InstalledRole, CatalogModel::PreviewFileRole});
        }
    }
    emit countsChanged();
    if (!m_selectedId.isEmpty()) emit selectionChanged();
}

// ── Filtering & Sorting ─────────────────────────────────────────────────────

void Catalog::setQuery(const QString &q) {
    if (m_query == q) return;
    m_query = q;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setCategory(const QString &cat) {
    if (m_category == cat) return;
    m_category = cat;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setSourceFilter(const QString &src) {
    if (m_sourceFilter == src) return;
    m_sourceFilter = src;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setVariableOnly(bool on) {
    if (m_variableOnly == on) return;
    m_variableOnly = on;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setScriptFilter(const QString &script) {
    if (m_scriptFilter == script) return;
    m_scriptFilter = script;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setSortBy(const QString &sort) {
    if (m_sortBy == sort) return;
    m_sortBy = sort;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setHideNoto(bool hide) {
    if (m_hideNoto == hide) return;
    m_hideNoto = hide;
    emit filterChanged();
    rebuildModel();
}

void Catalog::setSampleText(const QString &text) {
    if (m_sampleText == text) return;
    m_sampleText = text;
    emit sampleTextChanged();
    m_sampleDebounce.start();
}

void Catalog::resetFilters() {
    m_query.clear();
    m_category.clear();
    m_sourceFilter = QStringLiteral("all");
    m_variableOnly = false;
    m_scriptFilter.clear();
    emit filterChanged();
    rebuildModel();
}

void Catalog::rebuildModel() {
    const QString q = m_query.trimmed().toLower();
    QList<CatalogFamily> filtered;
    filtered.reserve(m_all.size());

    for (const CatalogFamily &e : m_all) {
        if (m_sourceFilter == QLatin1String("google") && e.source != QLatin1String("google")) continue;
        if (m_sourceFilter == QLatin1String("indie") && e.source != QLatin1String("indie")) continue;
        if (m_sourceFilter == QLatin1String("shortlist") && !e.shortlisted) continue;
        if (m_sourceFilter == QLatin1String("installed") && !e.installed) continue;

        // Hide per-script Noto families unless the user is searching or explicitly showing them.
        if (m_hideNoto && e.isNoto && q.isEmpty() && m_sourceFilter != QLatin1String("shortlist") && m_sourceFilter != QLatin1String("installed"))
            continue;

        if (!m_category.isEmpty() && e.category.compare(m_category, Qt::CaseInsensitive) != 0) continue;
        if (m_variableOnly && !e.variable) continue;
        if (!m_scriptFilter.isEmpty() && !e.subsets.contains(m_scriptFilter, Qt::CaseInsensitive)) continue;

        if (!q.isEmpty()) {
            bool match = e.family.toLower().contains(q)
                      || e.designersText().toLower().contains(q)
                      || e.foundry.toLower().contains(q)
                      || e.category.toLower().contains(q)
                      || e.description.toLower().contains(q);
            if (!match) continue;
        }
        filtered.append(e);
    }

    std::sort(filtered.begin(), filtered.end(), [this](const CatalogFamily &a, const CatalogFamily &b) {
        if (m_sortBy == QLatin1String("name"))
            return a.family.compare(b.family, Qt::CaseInsensitive) < 0;
        if (m_sortBy == QLatin1String("trending")) {
            if (a.trending != b.trending) return a.trending < b.trending;
            return a.popularity < b.popularity;
        }
        if (m_sortBy == QLatin1String("newest")) {
            if (a.dateAdded != b.dateAdded) return a.dateAdded > b.dateAdded;
            return a.popularity < b.popularity;
        }
        if (m_sortBy == QLatin1String("styles")) {
            if (a.styles.size() != b.styles.size()) return a.styles.size() > b.styles.size();
            return a.popularity < b.popularity;
        }
        // Default: "popular" — interleave curated indie highlights nicely when browsing "all"
        if (a.popularity != b.popularity) return a.popularity < b.popularity;
        return a.family.compare(b.family, Qt::CaseInsensitive) < 0;
    });

    m_model.setEntries(std::move(filtered));
    emit countsChanged();
}

// ── Preview streaming & disk cache ──────────────────────────────────────────

QString Catalog::previewTextKey() const {
    const QString t = m_sampleText.trimmed();
    return t.isEmpty() ? QStringLiteral("The quick brown fox jumps over the lazy dog") : t;
}

QString Catalog::previewCachePath(const CatalogFamily &entry, const QString &text) const {
    if (entry.source == QLatin1String("indie")) {
        const QString ext = entry.previewUrl.endsWith(QStringLiteral(".otf"), Qt::CaseInsensitive)
            ? QStringLiteral(".otf") : QStringLiteral(".ttf");
        return previewCacheDir() + QLatin1Char('/') + entry.id + ext;
    }
    // Include the family name + sample text in the subset so both the display
    // title and sample sentence render crisply in a single ~5-12 KB TTF!
    const QString combined = entry.family + QLatin1Char(' ') + text + QStringLiteral(" AaBbCc0123456789");
    const QByteArray hash = QCryptographicHash::hash(combined.toUtf8(), QCryptographicHash::Sha1).toHex().left(12);
    return previewCacheDir() + QLatin1Char('/') + entry.id + QLatin1Char('-') + QString::fromLatin1(hash) + QStringLiteral(".ttf");
}

void Catalog::requestPreview(const QString &id) {
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) return;
    CatalogFamily &e = m_all[it.value()];

    if (!e.previewFile.isEmpty() && QFileInfo::exists(e.previewFile)) return;

    const QString cp = previewCachePath(e, previewTextKey());
    if (QFileInfo::exists(cp) && QFileInfo(cp).size() > 256) {
        e.previewFile = cp;
        m_model.updateEntry(id, e, {CatalogModel::PreviewFileRole});
        emit previewReady(id, cp);
        if (m_selectedId == id) emit selectionChanged();
        return;
    }

    if (m_previewInFlight.contains(id)) return;
    // LIFO priority: remove if already queued and push to the back so the most
    // recently scrolled-into-view cards load first.
    m_previewQueue.removeAll(id);
    m_previewQueue.append(id);
    // Cap queue to avoid fetching cards long scrolled past.
    while (m_previewQueue.size() > 48) m_previewQueue.removeFirst();
    pumpPreviewQueue();
}

void Catalog::pumpPreviewQueue() {
    while (m_activePreviews < kMaxConcurrentPreviews && !m_previewQueue.isEmpty()) {
        const QString id = m_previewQueue.takeFirst();
        const auto it = m_indexById.constFind(id);
        if (it == m_indexById.cend()) continue;
        const CatalogFamily &e = m_all.at(it.value());
        if (!e.previewFile.isEmpty() && QFileInfo::exists(e.previewFile)) continue;
        if (m_previewInFlight.contains(id)) continue;

        const QString cp = previewCachePath(e, previewTextKey());
        m_previewInFlight.insert(id);
        ++m_activePreviews;

        if (e.source == QLatin1String("indie") && !e.previewUrl.isEmpty()) {
            fetchDirectPreview(id, e.previewUrl, cp);
        } else {
            const QString combined = e.family + QLatin1Char(' ') + previewTextKey() + QStringLiteral(" AaBbCc0123456789");
            fetchGooglePreview(id, e.family, combined, cp);
        }
    }
}

void Catalog::fetchGooglePreview(const QString &id, const QString &family, const QString &text, const QString &cachePath) {
    // Deduplicate characters so the URL stays compact and Google returns the
    // smallest possible subsetted TTF (usually 3-10 KB).
    QString uniqueChars;
    QSet<QChar> seen;
    for (const QChar ch : text) {
        if (!seen.contains(ch)) { seen.insert(ch); uniqueChars.append(ch); }
    }

    QUrl url(QString::fromLatin1(kGoogleCss2Base));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("family"), family);
    q.addQueryItem(QStringLiteral("text"), uniqueChars);
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QString::fromLatin1(kTtfUserAgent));
    req.setTransferTimeout(12000);

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id, cachePath] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            m_previewInFlight.remove(id);
            --m_activePreviews;
            pumpPreviewQueue();
            return;
        }
        const QString fontUrl = extractCssFontUrl(reply->readAll());
        if (fontUrl.isEmpty()) {
            m_previewInFlight.remove(id);
            --m_activePreviews;
            pumpPreviewQueue();
            return;
        }
        fetchDirectPreview(id, fontUrl, cachePath);
    });
}

void Catalog::fetchDirectPreview(const QString &id, const QString &url, const QString &cachePath) {
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Omatype/0.2"));
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
    req.setTransferTimeout(15000);

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id, cachePath] {
        reply->deleteLater();
        m_previewInFlight.remove(id);
        --m_activePreviews;

        if (reply->error() == QNetworkReply::NoError) {
            const QByteArray bytes = reply->readAll();
            if (looksLikeFontFile(bytes)) {
                QSaveFile sf(cachePath);
                if (sf.open(QIODevice::WriteOnly)) {
                    sf.write(bytes);
                    if (sf.commit()) {
                        const auto it = m_indexById.constFind(id);
                        if (it != m_indexById.cend()) {
                            m_all[it.value()].previewFile = cachePath;
                            m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::PreviewFileRole});
                            emit previewReady(id, cachePath);
                            if (m_selectedId == id) emit selectionChanged();
                        }
                    }
                }
            }
        }
        pumpPreviewQueue();
    });
}

// ── Selection & Manifest ────────────────────────────────────────────────────

void Catalog::selectFamily(const QString &id) {
    if (m_selectedId == id) return;
    m_selectedId = id;
    emit selectionChanged();
    emit manifestChanged();

    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) return;

    requestPreview(id);
    const CatalogFamily &e = m_all.at(it.value());
    if (e.source == QLatin1String("google") && !e.manifestLoaded) {
        fetchGoogleManifest(id);
    }
}

void Catalog::fetchGoogleManifest(const QString &id, std::function<void(bool)> callback) {
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) {
        if (callback) callback(false);
        return;
    }
    const QString family = m_all.at(it.value()).family;

    QUrl url(QString::fromLatin1(kGoogleDownloadListBase));
    QUrlQuery q;
    q.addQueryItem(QStringLiteral("family"), family);
    url.setQuery(q);

    if (id == m_selectedId) {
        m_loadingManifest = true;
        emit manifestChanged();
    }

    QNetworkRequest req(url);
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Omatype/0.2"));
    req.setTransferTimeout(15000);

    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id, callback] {
        reply->deleteLater();
        bool ok = false;
        if (reply->error() == QNetworkReply::NoError) {
            QList<CatalogFile> files;
            QString lic;
            if (parseGoogleDownloadManifest(reply->readAll(), &files, &lic) && !files.isEmpty()) {
                const auto idx = m_indexById.constFind(id);
                if (idx != m_indexById.cend()) {
                    CatalogFamily &e = m_all[idx.value()];
                    e.files = std::move(files);
                    e.licenseText = lic;
                    if (lic.contains(QStringLiteral("Apache License"), Qt::CaseInsensitive))
                        e.license = QStringLiteral("Apache 2.0");
                    else if (lic.contains(QStringLiteral("Ubuntu Font Licence"), Qt::CaseInsensitive))
                        e.license = QStringLiteral("Ubuntu Font Licence");
                    else if (lic.contains(QStringLiteral("SIL Open Font License"), Qt::CaseInsensitive))
                        e.license = QStringLiteral("SIL OFL 1.1");
                    e.manifestLoaded = true;
                    ok = true;
                }
            }
        }
        if (id == m_selectedId) {
            m_loadingManifest = false;
            emit manifestChanged();
            emit selectionChanged();
        }
        if (callback) callback(ok);
    });
}

QVariantMap Catalog::selectedFamily() const {
    const auto it = m_indexById.constFind(m_selectedId);
    if (it == m_indexById.cend()) return {};
    const CatalogFamily &e = m_all.at(it.value());

    QVariantList axesList;
    for (const CatalogAxis &a : e.axes) {
        axesList.append(QVariantMap{
            {QStringLiteral("tag"), a.tag},
            {QStringLiteral("min"), a.min},
            {QStringLiteral("max"), a.max},
            {QStringLiteral("defaultValue"), a.defaultValue},
        });
    }

    return {
        {QStringLiteral("id"), e.id},
        {QStringLiteral("family"), e.family},
        {QStringLiteral("source"), e.source},
        {QStringLiteral("sourceLabel"), e.sourceLabel},
        {QStringLiteral("foundry"), e.foundry},
        {QStringLiteral("designers"), e.designers},
        {QStringLiteral("designersText"), e.designersText()},
        {QStringLiteral("category"), e.category},
        {QStringLiteral("license"), e.license},
        {QStringLiteral("licenseText"), e.licenseText},
        {QStringLiteral("description"), e.description},
        {QStringLiteral("homepage"), e.homepage},
        {QStringLiteral("repoUrl"), e.repoUrl},
        {QStringLiteral("subsets"), e.subsets},
        {QStringLiteral("styles"), e.styles},
        {QStringLiteral("styleCount"), std::max<int>(1, e.styles.size())},
        {QStringLiteral("weightRange"), e.weightRangeText()},
        {QStringLiteral("variable"), e.variable},
        {QStringLiteral("axes"), axesList},
        {QStringLiteral("axesSummary"), e.axesSummary()},
        {QStringLiteral("previewFile"), e.previewFile},
        {QStringLiteral("installed"), e.installed},
        {QStringLiteral("installing"), e.installing},
        {QStringLiteral("shortlisted"), e.shortlisted},
        {QStringLiteral("dateAdded"), e.dateAdded},
        {QStringLiteral("popularity"), e.popularity},
    };
}

QVariantList Catalog::selectedFiles() const {
    QVariantList out;
    const auto it = m_indexById.constFind(m_selectedId);
    if (it == m_indexById.cend()) return out;
    for (const CatalogFile &f : m_all.at(it.value()).files) {
        out.append(QVariantMap{
            {QStringLiteral("filename"), f.filename},
            {QStringLiteral("url"), f.url},
            {QStringLiteral("style"), f.style},
            {QStringLiteral("weight"), f.weight},
            {QStringLiteral("italic"), f.italic},
            {QStringLiteral("variable"), f.variable},
        });
    }
    return out;
}

// ── 1-Click Install & Uninstall ─────────────────────────────────────────────

void Catalog::installFamily(const QString &id, bool preferVariable, const QStringList &selectedFilenames) {
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend() || m_installingIds.contains(id)) return;

    m_installingIds.insert(id);
    m_all[it.value()].installing = true;
    m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::InstallingRole});
    if (m_selectedId == id) emit selectionChanged();
    setInstallStatus(tr("Downloading %1…").arg(m_all.at(it.value()).family));

    if (m_all.at(it.value()).source == QLatin1String("google") && !m_all.at(it.value()).manifestLoaded) {
        fetchGoogleManifest(id, [this, id, preferVariable, selectedFilenames](bool ok) {
            if (!ok) {
                const auto idx = m_indexById.constFind(id);
                if (idx != m_indexById.cend()) {
                    m_all[idx.value()].installing = false;
                    m_model.updateEntry(id, m_all.at(idx.value()), {CatalogModel::InstallingRole});
                }
                m_installingIds.remove(id);
                if (m_selectedId == id) emit selectionChanged();
                const QString msg = tr("Could not fetch download manifest for %1").arg(id);
                setInstallStatus(msg);
                if (m_backend) m_backend->setStatus(msg, true);
                emit installFinished(id, false, msg);
                return;
            }
            startInstallDownload(id, preferVariable, selectedFilenames);
        });
        return;
    }

    startInstallDownload(id, preferVariable, selectedFilenames);
}

void Catalog::startInstallDownload(const QString &id, bool preferVariable, const QStringList &selectedFilenames) {
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) return;
    const CatalogFamily entry = m_all.at(it.value());

    QList<CatalogFile> toDownload;
    if (!selectedFilenames.isEmpty()) {
        for (const CatalogFile &cf : entry.files)
            if (selectedFilenames.contains(cf.filename)) toDownload.append(cf);
    } else if (preferVariable) {
        for (const CatalogFile &cf : entry.files)
            if (cf.variable) toDownload.append(cf);
        if (toDownload.isEmpty()) toDownload = entry.files;
    } else {
        for (const CatalogFile &cf : entry.files)
            if (!cf.variable) toDownload.append(cf);
        if (toDownload.isEmpty()) toDownload = entry.files;
    }

    if (toDownload.isEmpty()) {
        m_installingIds.remove(id);
        m_all[it.value()].installing = false;
        m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::InstallingRole});
        if (m_selectedId == id) emit selectionChanged();
        const QString msg = tr("No downloadable font files found for %1").arg(entry.family);
        setInstallStatus(msg);
        if (m_backend) m_backend->setStatus(msg, true);
        emit installFinished(id, false, msg);
        return;
    }

    const QString root = Backend::userFontRoot();
    const QString dirName = Backend::slug(entry.family);
    const QString dest = root + QLatin1Char('/') + (dirName.isEmpty() ? entry.id : dirName);
    QDir().mkpath(dest);

    struct BatchState {
        int remaining = 0;
        int written = 0;
        QString firstError;
        QString dest;
        QString family;
        QString sourceLabel;
        QString licenseText;
    };
    auto state = std::make_shared<BatchState>();
    state->remaining = toDownload.size();
    state->dest = dest;
    state->family = entry.family;
    state->sourceLabel = entry.sourceLabel;
    state->licenseText = entry.licenseText;

    for (const CatalogFile &cf : toDownload) {
        QNetworkRequest req{QUrl(cf.url)};
        req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Omatype/0.2"));
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        req.setTransferTimeout(30000);

        QNetworkReply *reply = m_nam.get(req);
        connect(reply, &QNetworkReply::finished, this, [this, reply, id, cf, state] {
            reply->deleteLater();
            if (reply->error() != QNetworkReply::NoError) {
                if (state->firstError.isEmpty()) state->firstError = reply->errorString();
            } else {
                const QByteArray bytes = reply->readAll();
                if (!looksLikeFontFile(bytes)) {
                    if (state->firstError.isEmpty())
                        state->firstError = tr("%1 is not a valid OpenType/TrueType file").arg(cf.filename);
                } else {
                    const QString target = state->dest + QLatin1Char('/') + cf.filename;
                    QSaveFile sf(target);
                    if (sf.open(QIODevice::WriteOnly)) {
                        sf.write(bytes);
                        if (sf.commit()) {
                            QFile::setPermissions(target, QFile::ReadOwner | QFile::WriteOwner | QFile::ReadGroup | QFile::ReadOther);
                            ++state->written;
                        } else if (state->firstError.isEmpty()) {
                            state->firstError = sf.errorString();
                        }
                    } else if (state->firstError.isEmpty()) {
                        state->firstError = sf.errorString();
                    }
                }
            }

            if (--state->remaining > 0) return;

            // Write license file alongside the font for clean attribution.
            if (state->written > 0 && !state->licenseText.isEmpty()) {
                QSaveFile lf(state->dest + QStringLiteral("/OFL.txt"));
                if (lf.open(QIODevice::WriteOnly)) {
                    lf.write(state->licenseText.toUtf8());
                    lf.commit();
                }
            }

            m_installingIds.remove(id);
            const auto idx = m_indexById.constFind(id);
            if (idx != m_indexById.cend()) {
                m_all[idx.value()].installing = false;
                if (state->written > 0) m_all[idx.value()].installed = true;
                m_model.updateEntry(id, m_all.at(idx.value()), {CatalogModel::InstallingRole, CatalogModel::InstalledRole});
            }
            if (m_selectedId == id) emit selectionChanged();

            if (state->written == 0) {
                const QString msg = tr("Install failed for %1: %2").arg(state->family, state->firstError);
                setInstallStatus(msg);
                if (m_backend) m_backend->setStatus(msg, true);
                emit installFinished(id, false, msg);
                return;
            }

            QString msg = state->written == 1
                ? tr("Installed %1 from %2.").arg(state->family, state->sourceLabel)
                : tr("Installed %1 (%2 files) from %3.").arg(state->family).arg(state->written).arg(state->sourceLabel);

            if (m_backend) {
                const QStringList apps = m_backend->runningDesignApps();
                if (!apps.isEmpty())
                    msg += tr(" Restart %1 to pick it up.").arg(apps.join(QStringLiteral(", ")));
                m_backend->recordCatalogInstall(state->family, state->sourceLabel, state->dest);
                m_backend->setStatus(msg);
            }
            setInstallStatus(msg);
            emit countsChanged();
            emit installFinished(id, true, msg);
        });
    }
}

void Catalog::uninstallFamily(const QString &id) {
    if (!m_backend) return;
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) return;
    const QString familyName = m_all.at(it.value()).family;

    const FontFamily *f = m_backend->family(familyName);
    if (!f) {
        // Fallback: try matching by normalized id.
        for (const FontFamily &cand : m_backend->allFamilies()) {
            if (normalizeId(cand.name) == id) { f = &cand; break; }
        }
    }
    if (!f) return;

    const QStringList removable = m_backend->removableFiles(*f);
    if (removable.isEmpty()) {
        m_backend->setStatus(tr("%1 is a system font; deactivate it instead.").arg(familyName), true);
        return;
    }
    const QString err = m_backend->removeFamilyFiles(removable);
    if (!err.isEmpty()) {
        m_backend->setStatus(tr("Remove failed: %1").arg(err), true);
        return;
    }
    m_all[it.value()].installed = false;
    m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::InstalledRole});
    if (m_selectedId == id) emit selectionChanged();
    m_backend->setStatus(tr("Removed %1.").arg(familyName));
    m_backend->refresh();
}

// ── Shortlist (Suitcase-style exploration basket) ───────────────────────────

void Catalog::toggleShortlist(const QString &id) {
    const auto it = m_indexById.constFind(id);
    if (it == m_indexById.cend()) return;

    const bool nowOn = !m_shortlist.contains(id);
    if (nowOn) m_shortlist.append(id);
    else m_shortlist.removeAll(id);

    m_all[it.value()].shortlisted = nowOn;
    m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::ShortlistedRole});
    saveShortlist();
    emit shortlistChanged();
    if (m_selectedId == id) emit selectionChanged();
    if (m_sourceFilter == QLatin1String("shortlist")) rebuildModel();
}

void Catalog::clearShortlist() {
    if (m_shortlist.isEmpty()) return;
    const QStringList old = m_shortlist;
    m_shortlist.clear();
    for (const QString &id : old) {
        const auto it = m_indexById.constFind(id);
        if (it != m_indexById.cend()) {
            m_all[it.value()].shortlisted = false;
            m_model.updateEntry(id, m_all.at(it.value()), {CatalogModel::ShortlistedRole});
        }
    }
    saveShortlist();
    emit shortlistChanged();
    if (!m_selectedId.isEmpty()) emit selectionChanged();
    if (m_sourceFilter == QLatin1String("shortlist")) rebuildModel();
}

void Catalog::installShortlist() {
    for (const QString &id : m_shortlist) {
        const auto it = m_indexById.constFind(id);
        if (it != m_indexById.cend() && !m_all.at(it.value()).installed) {
            installFamily(id, true, {});
        }
    }
}

QVariantList Catalog::shortlistItems() const {
    QVariantList out;
    for (const QString &id : m_shortlist) {
        const auto it = m_indexById.constFind(id);
        if (it == m_indexById.cend()) continue;
        const CatalogFamily &e = m_all.at(it.value());
        out.append(QVariantMap{
            {QStringLiteral("id"), e.id},
            {QStringLiteral("family"), e.family},
            {QStringLiteral("designersText"), e.designersText()},
            {QStringLiteral("installed"), e.installed},
            {QStringLiteral("installing"), e.installing},
        });
    }
    return out;
}

void Catalog::saveShortlist() {
    QSettings s;
    s.setValue(QStringLiteral("catalog/shortlist"), m_shortlist);
}

void Catalog::loadShortlist() {
    QSettings s;
    m_shortlist = s.value(QStringLiteral("catalog/shortlist")).toStringList();
}

void Catalog::setInstallStatus(const QString &msg) {
    m_installStatus = msg;
    emit installStateChanged();
}

void Catalog::openUrl(const QString &url) const {
    if (!url.trimmed().isEmpty()) QDesktopServices::openUrl(QUrl(url.trimmed()));
}

// ── CLI / Headless helpers ──────────────────────────────────────────────────

QList<CatalogFamily> Catalog::searchFamilies(const QString &query, const QString &category, const QString &source, int limit) const {
    const QString q = query.trimmed().toLower();
    QList<CatalogFamily> matches;
    for (const CatalogFamily &e : m_all) {
        if (!source.isEmpty() && source != QLatin1String("all") && e.source != source) continue;
        if (!category.isEmpty() && e.category.compare(category, Qt::CaseInsensitive) != 0) continue;
        if (!q.isEmpty()) {
            const bool hit = e.family.toLower().contains(q)
                          || e.designersText().toLower().contains(q)
                          || e.foundry.toLower().contains(q)
                          || e.category.toLower().contains(q);
            if (!hit) continue;
        }
        matches.append(e);
    }
    std::sort(matches.begin(), matches.end(), [](const CatalogFamily &a, const CatalogFamily &b) {
        if (a.popularity != b.popularity) return a.popularity < b.popularity;
        return a.family.compare(b.family, Qt::CaseInsensitive) < 0;
    });
    if (limit > 0 && matches.size() > limit) matches.resize(limit);
    return matches;
}

const CatalogFamily *Catalog::findByNameOrId(const QString &nameOrId) const {
    const QString needle = normalizeId(nameOrId);
    const auto it = m_indexById.constFind(needle);
    if (it != m_indexById.cend()) return &m_all.at(it.value());
    for (const CatalogFamily &e : m_all) {
        if (e.family.compare(nameOrId.trimmed(), Qt::CaseInsensitive) == 0) return &e;
    }
    return nullptr;
}

QString Catalog::installFamilyBlocking(const QString &nameOrId, bool preferVariable, const QStringList &filenames, QString *installedDir, int *fileCount) {
    const CatalogFamily *found = findByNameOrId(nameOrId);
    if (!found) return tr("No catalog font named \"%1\"").arg(nameOrId);

    const QString id = found->id;
    QString resultError;
    bool done = false;
    QEventLoop loop;
    auto conn = connect(this, &Catalog::installFinished, &loop, [&](const QString &fid, bool ok, const QString &msg) {
        if (fid != id) return;
        done = true;
        if (!ok) resultError = msg;
        loop.quit();
    });

    installFamily(id, preferVariable, filenames);
    if (!done) loop.exec();
    disconnect(conn);

    if (resultError.isEmpty()) {
        const QString dir = Backend::userFontRoot() + QLatin1Char('/') + Backend::slug(found->family);
        if (installedDir) *installedDir = dir;
        if (fileCount) {
            const QStringList installed = QDir(dir).entryList({QStringLiteral("*.ttf"), QStringLiteral("*.otf"), QStringLiteral("*.ttc")}, QDir::Files);
            *fileCount = installed.size();
        }
        // Wait for fc-cache to finish before CLI exits.
        QProcess fc;
        fc.start(QStringLiteral("fc-cache"), {QStringLiteral("-f"), QStringLiteral("--"), Backend::userFontRoot()});
        fc.waitForFinished(60000);
    }
    return resultError;
}
