extends RefCounted

const CODES := ["en", "es", "fr"]
const NAMES := ["English", "Español", "Français"]

const TABLE := {
	"es": {
		"Settings": "Ajustes", "Audio": "Audio", "Controls": "Controles", "Graphics": "Gráficos", "Language": "Idioma",
		"Master Volume": "Volumen general", "Music": "Música", "Effects": "Efectos",
		"Mouse Sensitivity": "Sensibilidad del ratón", "Invert Look": "Invertir vista vertical",
		"Reset": "Restablecer", "Back": "Volver", "Reset keys": "Restablecer teclas",
		"Click a key to change it": "Haz clic en una tecla para cambiarla",
		"Press a key...": "Pulsa una tecla...",
		"Press the new key, or Esc to cancel": "Pulsa la nueva tecla, o Esc para cancelar",
		"Move forward": "Avanzar", "Move back": "Retroceder", "Move left": "Izquierda", "Move right": "Derecha",
		"Jump": "Saltar", "Interact": "Interactuar", "Change difficulty": "Cambiar dificultad",
		"Unlock level": "Desbloquear nivel", "Change view": "Cambiar vista",
		"Window Mode": "Modo de ventana", "Windowed": "Ventana", "Fullscreen": "Pantalla completa",
		"Vertical Sync": "Sincronía vertical", "Frame Rate Limit": "Límite de FPS", "Unlimited": "Sin límite",
		"Field of View": "Campo de visión", "Head Bob": "Balanceo de cabeza", "Render Scale": "Escala de render",
		"Anti-aliasing": "Suavizado", "Shadows": "Sombras", "Glow": "Resplandor", "Brightness": "Brillo",
		"Off": "No", "Low": "Bajo", "Medium": "Medio", "High": "Alto", "ON": "SÍ", "OFF": "NO",
		"Resume": "Continuar", "Paused": "En pausa", "Save and back to menu": "Guardar y volver al menú",
		"Esc to resume": "Esc para continuar", "New game": "Nueva partida", "Continue": "Continuar",
		"Credits": "Créditos", "Quit": "Salir",
		"Language changes apply to menus and settings.": "El idioma se aplica a los menús y ajustes.",
	},
	"fr": {
		"Settings": "Options", "Audio": "Audio", "Controls": "Commandes", "Graphics": "Graphismes", "Language": "Langue",
		"Master Volume": "Volume général", "Music": "Musique", "Effects": "Effets",
		"Mouse Sensitivity": "Sensibilité de la souris", "Invert Look": "Inverser l'axe vertical",
		"Reset": "Réinitialiser", "Back": "Retour", "Reset keys": "Réinitialiser les touches",
		"Click a key to change it": "Cliquez sur une touche pour la changer",
		"Press a key...": "Appuyez sur une touche...",
		"Press the new key, or Esc to cancel": "Appuyez sur la nouvelle touche, ou Échap pour annuler",
		"Move forward": "Avancer", "Move back": "Reculer", "Move left": "Gauche", "Move right": "Droite",
		"Jump": "Sauter", "Interact": "Interagir", "Change difficulty": "Changer la difficulté",
		"Unlock level": "Débloquer le niveau", "Change view": "Changer de vue",
		"Window Mode": "Mode d'affichage", "Windowed": "Fenêtré", "Fullscreen": "Plein écran",
		"Vertical Sync": "Synchro verticale", "Frame Rate Limit": "Limite d'IPS", "Unlimited": "Illimité",
		"Field of View": "Champ de vision", "Head Bob": "Balancement de la tête", "Render Scale": "Échelle de rendu",
		"Anti-aliasing": "Anticrénelage", "Shadows": "Ombres", "Glow": "Lueur", "Brightness": "Luminosité",
		"Off": "Non", "Low": "Bas", "Medium": "Moyen", "High": "Élevé", "ON": "OUI", "OFF": "NON",
		"Resume": "Reprendre", "Paused": "Pause", "Save and back to menu": "Sauvegarder et retour au menu",
		"Esc to resume": "Échap pour reprendre", "New game": "Nouvelle partie", "Continue": "Continuer",
		"Credits": "Crédits", "Quit": "Quitter",
		"Language changes apply to menus and settings.": "La langue s'applique aux menus et aux options.",
	},
}


static func tr_text(code: String, text: String) -> String:
	if code == "en" or not TABLE.has(code):
		return text
	return TABLE[code].get(text, text)
