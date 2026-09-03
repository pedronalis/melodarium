# Security Policy / Política de Segurança

## Supported versions / Versões suportadas

Security fixes target the latest public release and `main`. Older preview builds may be asked to
upgrade before a report can be reproduced.

Correções de segurança miram a release pública mais recente e a `main`. Pode ser necessário
atualizar previews antigos antes de reproduzir um relato.

## Report privately / Relate em privado

Do **not** open a public issue for a suspected vulnerability. Use GitHub's private vulnerability
reporting page:

**https://github.com/pedronalis/melodarium/security/advisories/new**

Não abra issue pública para uma possível vulnerabilidade. Use a página acima para relato privado
de vulnerabilidades do GitHub.

Include, when available / Inclua, quando possível:

- affected commit or version / commit ou versão afetada;
- Fedora/Linux version and Wayland or X11 session / versão do Fedora/Linux e sessão Wayland ou X11;
- minimal reproduction steps / passos mínimos para reproduzir;
- expected impact and required user interaction / impacto esperado e interação exigida do usuário;
- sanitized logs or a disposable fixture / logs higienizados ou fixture descartável.

Never upload real music, podcast files, a Melodarium database, home-directory paths, feed tokens or
other personal data. Nunca envie músicas, episódios, banco do Melodarium, caminhos da pasta pessoal,
tokens de feeds ou outros dados pessoais.

The maintainer will coordinate validation, remediation and disclosure through the private advisory.
No fixed response-time SLA is promised for this independent project.

O mantenedor coordenará validação, correção e divulgação pelo advisory privado. Este projeto
independente não promete um SLA fixo de resposta.

## Regular bugs / Bugs comuns

Crashes or failures without a security impact belong in the bilingual bug-report form. Travamentos
ou falhas sem impacto de segurança devem usar o formulário bilíngue de bug.
