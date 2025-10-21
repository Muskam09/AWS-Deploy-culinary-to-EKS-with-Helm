from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView
from rest_framework.permissions import AllowAny

class PublicSpectacularAPIView(SpectacularAPIView):
    permission_classes = [AllowAny]

class PublicSwaggerView(SpectacularSwaggerView):
    permission_classes = [AllowAny]
