/// Where the AI Answer column gets its reply.
enum AiBackend {
  /// LM Studio local server.
  lmStudio,

  /// On-device LiteRT-LM `.litertlm` model.
  liteRtLm;

  static AiBackend fromStorage(String? raw) {
    if (raw == liteRtLm.storageValue) return AiBackend.liteRtLm;
    return AiBackend.lmStudio;
  }

  String get storageValue => switch (this) {
    AiBackend.lmStudio => 'lm_studio',
    AiBackend.liteRtLm => 'litert_lm',
  };
}
