#include "barconfig.hpp"

#include <qjsonarray.h>
#include <qjsonobject.h>

namespace caelestia::shell::config {

bool BarSections::syncJson(const QJsonValue& json, QList<settings::Diagnostic>& diagnostics) {
    if (json.isArray()) {
        QJsonArray buckets[3];
        int bucket = 0;

        for (const auto& entry : json.toArray()) {
            const auto obj = entry.toObject();
            if (obj.value(u"id"_s).toString() == u"spacer"_s) {
                if (bucket < 2)
                    ++bucket;
                continue;
            }
            buckets[bucket].append(entry);
        }

        // Upstream's default layout uses one spacer to split left and right;
        // map the second bucket to `end` rather than `center`.
        if (bucket == 1) {
            buckets[2] = buckets[1];
            buckets[1] = QJsonArray();
        }

        QJsonObject migrated{
            { u"start"_s, buckets[0] },
            { u"center"_s, buckets[1] },
            { u"end"_s, buckets[2] },
        };
        return ObjectNode::syncJson(migrated, diagnostics);
    }

    return ObjectNode::syncJson(json, diagnostics);
}

} // namespace caelestia::shell::config
