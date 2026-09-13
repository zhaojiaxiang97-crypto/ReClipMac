#pragma once

#include "YtDlpTypes.h"
#include <QFuture>

namespace ReClip::YtDlp {

// All Python objects stay on one interpreter thread. Futures contain values.
QFuture<Result> submitPython(const Request &request, const CancelToken &cancel);

} // namespace ReClip::YtDlp
