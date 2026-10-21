# VBS Blocker

Script per diagnosticare e disabilitare, su Windows Server, alcune funzionalità
di sicurezza basate sulla virtualizzazione (VBS), tra cui HVCI/Integrità della
memoria, Credential Guard e l'avvio dell'hypervisor Windows.

## Perché condivido questa procedura

Nel mio caso la macchina Windows Server 2025 era virtualizzata su Proxmox VE.
Prima dell'intervento, l'apertura di Esplora file richiedeva circa 10 secondi e
la macchina era estremamente poco reattiva. Ho impiegato diversi giorni di
diagnosi prima di riuscire a stabilizzare il server e metterlo in produzione.

Condivido quindi questa esperienza perché possa essere utile a chi incontra
rallentamenti simili su Windows virtualizzato in Proxmox. Il risultato è
osservato nel mio ambiente e non costituisce una garanzia per altre
configurazioni.

> **Attenzione:** questa procedura riduce protezioni di sicurezza importanti.
> Non applicarla automaticamente a server di produzione. Prima di procedere:
> verificare le policy aziendali, le dipendenze da Hyper-V/WSL/Sandbox e le
> esigenze di Credential Guard, creare un backup e pianificare un riavvio.
> Testare prima su una VM e mantenere una console di amministrazione disponibile.

## Contenuto

- [`Disable-VBS.bat`](./Disable-VBS.bat): versione batch da eseguire come
  amministratore.
- [`Disable-VBS.ps1`](./Disable-VBS.ps1): versione PowerShell con controlli
  degli errori e messaggi espliciti.
- [`no vbs.htm`](./no%20vbs.htm): pagina HTML con istruzioni per distribuzione
  singola e tramite GPO.

Gli script impostano a `0` i valori di registro relativi a VBS, HVCI,
Credential Guard, Windows Hello e Kernel Shadow Stacks, quindi impostano
`hypervisorlaunchtype` e `vsmlaunchtype` su `off` tramite BCD. Le chiavi
potrebbero essere ricreate da Group Policy, MDM o da una configurazione di
sicurezza gestita: verificare sempre il risultato dopo il riavvio.

Lo script scrive anche le impostazioni equivalenti nelle chiavi di policy
locali di Windows sotto `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard`.
Questo permette di abbinare la configurazione del registro delle policy locali
alla configurazione runtime e BCD.

## Modalità di esecuzione

Puoi scegliere liberamente uno dei metodi seguenti:

- eseguire il file batch dopo averlo scaricato;
- scaricare il file PowerShell ed eseguirlo;
- eseguire direttamente il codice remoto con `irm | iex`;
- creare uno `scriptblock` in memoria e passargli l'argomento
  `-InstallStartupTask`, senza salvare manualmente il file.

Tutti i metodi richiedono una console elevata (amministratore). Il codice dei
file è disponibile nel repository e può essere verificato prima o dopo il
download.

### File batch scaricato

Per usare il batch, scaricare [`Disable-VBS.bat`](./Disable-VBS.bat) e avviarlo
con **Esegui come amministratore**. Da una console PowerShell è possibile
scaricarlo così:

```powershell
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.bat' -OutFile (Join-Path $env:TEMP 'Disable-VBS.bat')
Start-Process -FilePath (Join-Path $env:TEMP 'Disable-VBS.bat') -Verb RunAs -Wait
```

### File PowerShell scaricato

Aprire **PowerShell come amministratore**, spostarsi nella directory scaricata
ed eseguire:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Disable-VBS.ps1
```

In alternativa, fare clic con il tasto destro su `Disable-VBS.bat` e scegliere
**Esegui come amministratore**.

Lo script non riavvia automaticamente il computer. Dopo l'applicazione delle
modifiche, riavviare Windows e verificare lo stato con `msinfo32.exe` e con gli
strumenti amministrativi appropriati.

## Esecuzione remota da PowerShell

### Esecuzione una tantum

#### Download ed esecuzione del file

```powershell
$uri = 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.ps1'
$path = Join-Path $env:TEMP 'Disable-VBS.ps1'
Invoke-WebRequest -Uri $uri -OutFile $path
Get-FileHash $path -Algorithm SHA256
& $path
```

Il file resta disponibile in `$path`, quindi puoi visualizzarlo o verificarne
l'hash prima di eseguirlo.

#### Esecuzione diretta con `irm | iex`

Questo comando scarica il contenuto ed esegue subito lo script in memoria:

```powershell
irm 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.ps1' | iex
```

È la modalità diretta per l'esecuzione una tantum: non crea file locali e non
installa un'attività di avvio.

#### Esecuzione tramite scriptblock

Lo script può essere caricato in memoria e invocato come `scriptblock`:

```powershell
$uri = 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.ps1'
$script = Invoke-RestMethod -Uri $uri
& ([scriptblock]::Create($script))
```

Per passare l'argomento e installare il task di avvio direttamente dallo
scriptblock:

```powershell
$script = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.ps1'
& ([scriptblock]::Create($script)) -InstallStartupTask
```

Questa modalità evita di salvare manualmente il file `.ps1`; lo script copia
comunque una propria copia in `C:\ProgramData\VBS-Blocker` quando viene usato
con `-InstallStartupTask`.

### Installazione come attività di avvio

Per applicare nuovamente le impostazioni a ogni avvio, usare una console
PowerShell elevata e il comando seguente:

```powershell
$path = Join-Path $env:TEMP 'Disable-VBS.ps1'
irm 'https://raw.githubusercontent.com/r3bug/VBS-Blocker/main/Disable-VBS.ps1' -OutFile $path
& $path -InstallStartupTask
```

`-InstallStartupTask` copia lo script in
`C:\ProgramData\VBS-Blocker\Disable-VBS.ps1` e crea l'attività pianificata
**VBS Blocker - Apply at startup**, eseguita come `SYSTEM` con privilegi
elevati a ogni avvio. Le impostazioni vengono applicate subito.

Per rimuovere l'attività:

```powershell
Unregister-ScheduledTask -TaskName 'VBS Blocker - Apply at startup' -Confirm:$false
```

## Distribuzione tramite GPO

Qui ci sono due possibilità, da scegliere in base a ciò che ti serve:

- **Consultare il file HTML:** [`no vbs.htm`](./no%20vbs.htm) è un report/
  documento HTML scaricabile. Puoi aprirlo e copiare la configurazione GPO
  descritta al suo interno, seguendo la procedura passo per passo.
- **Applicare davvero la configurazione:** la GPO deve eseguire
  `Disable-VBS.ps1`, direttamente oppure tramite un wrapper `.cmd`. Il file
  HTML non viene eseguito dalla GPO e non è obbligatorio scaricarlo: serve solo
  come documentazione e come riferimento per ricreare la configurazione.

In altre parole: **o apri `no vbs.htm` e copi manualmente la configurazione
GPO, oppure distribuisci `Disable-VBS.ps1` tramite GPO**. Le due cose non sono
alternative da eseguire entrambe.

### Configurazione più completa: GPO più script

Se vuoi essere il più sicuro possibile che le impostazioni restino disabilitate,
puoi combinare i due livelli:

1. Apri `no vbs.htm` e ricrea nella GPO di dominio la configurazione indicata
   nel report, impostando su **Disabled** la policy **Turn On Virtualization
   Based Security** e le policy correlate.
2. Distribuisci anche `Disable-VBS.ps1` come script di avvio computer oppure
   come Scheduled Task eseguita come `SYSTEM`.
3. Dopo `gpupdate /force`, riavvia una macchina pilota e controlla `msinfo32.exe`
   e `Win32_DeviceGuard`.

In questa combinazione la GPO governa le impostazioni amministrative, mentre lo
script riapplica i valori di policy locali, le chiavi di sistema e i parametri
BCD. È un approccio ridondante utile quando vuoi evitare che una configurazione
locale o un componente di Windows riattivi la funzionalità.

Lo script non può però annullare una GPO di dominio che imposta nuovamente i
valori, un profilo MDM/Intune o un Credential Guard configurato con UEFI Lock:
queste configurazioni devono essere modificate alla fonte.

### Script di avvio del computer

1. Scaricare solo `Disable-VBS.ps1` dal repository. `no vbs.htm` è facoltativo
   e serve soltanto per consultare la procedura.
2. Copiare `Disable-VBS.ps1` in SYSVOL o in una share UNC leggibile dai
   computer, ad esempio
   `\\DOMINIO\SYSVOL\DOMINIO\scripts\Disable-VBS.ps1`.
3. In Group Policy Management creare o modificare una GPO collegata all'OU
   dei computer e aprire **Computer Configuration > Policies > Windows
   Settings > Scripts (Startup/Shutdown) > Startup**.
4. Aggiungere un wrapper `.cmd` dalla stessa share:

   ```bat
   @echo off
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\DOMINIO\SYSVOL\DOMINIO\scripts\Disable-VBS.ps1"
   ```

5. Garantire a `Domain Computers` i permessi di lettura sulla share, eseguire
   `gpupdate /force` su una VM pilota, riavviare e verificare con
   `msinfo32.exe`.

### Scheduled Task tramite Group Policy Preferences

In alternativa alla voce **Startup** precedente, usare
**Computer Configuration > Preferences > Control Panel Settings > Scheduled
Tasks** e creare un task eseguito come
`NT AUTHORITY\SYSTEM`, con trigger **At startup** e azione:

```text
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "\\DOMINIO\SYSVOL\DOMINIO\scripts\Disable-VBS.ps1"
```

Questa modalità permette di gestire dalla GPO trigger, tentativi e condizioni
del task. Testare sempre prima su una OU pilota. Non usare una lettera di unità:
all'avvio potrebbe non essere disponibile; usare sempre un percorso UNC.

## Windows Server virtualizzato su Proxmox VE

Se la macchina Windows è una VM su Proxmox VE, il problema può dipendere
anche dall'esposizione della virtualizzazione annidata (nested virtualization)
alla VM. Disabilitare l'hypervisor dentro Windows tramite BCD e rimuovere il
nested virtualization dalla configurazione CPU di Proxmox sono interventi
diversi: valutare entrambi separatamente e misurare il risultato.

### Rimuovere il nested virtualization dalla CPU della VM

Disabilitare l'avvio dell'hypervisor dentro Windows non equivale a rimuovere
la virtualizzazione annidata esposta dalla VM. Se la VM non deve eseguire
Hyper-V, WSL2, Windows Sandbox o altri hypervisor, spegnerla e valutare la
la rimozione del nested virtualization dalla configurazione CPU di Proxmox,
ad esempio:

```text
cpu: host,flags=-nested-virt
```

La modifica può essere effettuata dal file di configurazione QEMU della VM o
dalla GUI di Proxmox, secondo la versione in uso. Fare prima un backup e
verificare la sintassi/documentazione della propria versione; non modificare
una VM accesa.

Questa impostazione è separata dagli script Windows e, nel caso descritto,
ha prodotto il miglioramento più evidente. Non è però una garanzia: prima
escludere colli di bottiglia di storage, CPU, memoria, driver e configurazione
dell'host.

## Procedura diagnostica

1. Stabilire se la lentezza riguarda solo il gestionale o tutto Windows.
2. Controllare CPU, RAM, disco e storage sia sull'host Proxmox sia sulla VM.
3. Confrontare la configurazione CPU con una VM equivalente che funziona.
4. Verificare VBS, HVCI e Credential Guard con `msinfo32.exe` e gli strumenti
   amministrativi disponibili.
5. Determinare se il nested virtualization è realmente necessario.
6. Se non serve, testare la rimozione del nesting con backup e finestra di
   manutenzione.
7. Riavviare e misurare nuovamente mantenendo invariati gli altri parametri.
8. Valutare separatamente la disattivazione delle singole protezioni, secondo
   le policy dell'organizzazione.

## Risultato osservato nel mio ambiente

Nel mio ambiente Windows Server 2025 virtualizzato in Proxmox, con database,
Domain Controller, web application server e Terminal Server RDS, Esplora file
impiegava circa 10 secondi per avviarsi prima dell'intervento. Dopo la
disattivazione del nesting, si apriva in meno di 1 secondo e la reattività
generale è migliorata drasticamente. Il miglioramento complessivo osservato
era dell'ordine dell'80--90%.

Sono risultati osservati in quella configurazione, non una garanzia per altri
ambienti.

## Licenza

Distribuire questo repository con una licenza coerente con le policy della
propria organizzazione. Gli script sono forniti senza garanzia: chi li esegue
è responsabile della valutazione dell'impatto sul proprio ambiente.
