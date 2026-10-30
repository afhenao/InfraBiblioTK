// Crea el trabajo "bibliotk" (pipeline del Jenkinsfile de InfraBiblioTK) si todavía no existe.
// Corre en cada arranque de Jenkins; si el trabajo ya está, no lo toca
import hudson.plugins.git.BranchSpec
import hudson.plugins.git.GitSCM
import jenkins.model.Jenkins
import org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition
import org.jenkinsci.plugins.workflow.job.WorkflowJob

def jenkins = Jenkins.get()

if (jenkins.getItem("bibliotk") == null) {
  def repositorio = new GitSCM(
    GitSCM.createRepoList("https://github.com/afhenao/InfraBiblioTK.git", null),
    [new BranchSpec("*/master")],
    null, null, []
  )
  def trabajo = jenkins.createProject(WorkflowJob, "bibliotk")
  trabajo.setDescription("Actualiza los repositorios de BiblioTK, reconstruye las imágenes y despliega en este servidor")
  trabajo.setDefinition(new CpsScmFlowDefinition(repositorio, "Jenkinsfile"))
  trabajo.save()
  println("Trabajo bibliotk creado")
}
